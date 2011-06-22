#  quad_tree_accelerator.rb
#  quad-tree-accelerator
#
#  Created by Daniel Grigg on 22/06/11.
#  Copyright 2011 Daniel Grigg. All rights reserved.

require 'bbox'

# Operations for QuadTree bounding boxes.
class QuadBox
  def self.subdivideBBox(b)
    c = b.centre
    [BBox.new(b.min, Point3.new(c.x, c.y, b.max.z)),
      BBox.new(Point3.new(c.x, b.min.y, b.min.z), 
               Point3.new(b.max.x, c.y, b.max.z)),
      BBox.new(Point3.new(c.x, c.y, b.min.z), b.max),
      BBox.new(Point3.new(b.min.x, c.y, b.min.z), 
               Point3.new(c.x, b.max.y, b.max.z))]
  end
end

# A QuadTreeNode is a tree whose children are split against two fixed 
# orthogonal planes. A node consists of four children, split into four 
# even subspaces filling the parent space. Each space corresponds to a 
# real spatial extent. Only leaf nodes contain data, the amount of which 
# is defined to be n items or if we've reached a maximum depth.
#
# We currently store only points.  This won't suffice for any objects with
# a real spatial extent.  We must add support for storing primtives defined 
# by a BBox.
class QuadTreeNode
  # Children indices
  SW = 0
  SE = 1
  NE = 2
  NW = 3

  # Node's axis-aligned-bounding-box
  attr_reader :bbox
  # Items stored within this node.  Always nil for internal nodes. For leaves,
  # the #points is <= QuadTreeAccelerator::maxPointsPerNode or > 0 if node 
  # depth >= maxDepth.
  attr_accessor :points

  # Depth from root.  Root node is 0 depth.
  attr_reader :depth

  # Children nodes. For leaves, children is always nil. For internal nodes,
  # children is an array of [SW,SE,NE,NW] nodes, where each entry is either
  # nil (no child subspace) or a QuadTreeNode.
  attr_reader :children

  # Parent node, nil iff root.
  attr_accessor :parent

  # User-defined object corresponding to an internal node.
  attr_reader :group

  # Id in (SW,SE,NE,NW)
  attr_reader :childId

  # Initializer
  def initialize(points, bbox, childId, parent, maxDepth, heap, builder)
    raise ArgumentError if (!bbox)
    raise ArgumentError if !heap
    raise ArgumentError if (childId < SW || childId > NW)
    raise ArgumentError if (maxDepth < 0)
    @bbox = bbox
    @childId = childId
    @parent = parent
    @depth = parent ? parent.depth + 1 : 0
    @points = points
    return if (!points)

    parentGroup = parent ? parent.group : nil
    @group = builder.buildGroup(parentGroup, bbox) if builder

    if (depth >= maxDepth ||
        points.size <= QuadTreeAccelerator::maxPointsPerNode)
      points.each {|p| 
        buildPrimitive(p, heap, builder)
      } 
    else
      branch(maxDepth, heap, builder)
    end
  end

  # Destructor
  # Provided to support User-defined Builders that may need explit cleanup.
  def destroy(builder)
    if (children)
      children[SW].destroy(builder) if children[SW]
      children[SE].destroy(builder) if children[SE]
      children[NE].destroy(builder) if children[NE]
      children[NW].destroy(builder) if children[NW]
    end
    if (isLeaf?)
      points.each{|p| builder.destroyPrimitive(p) } if builder
    else
      # Little awkward, but skip the root node.
      builder.destroyGroup(group) if (builder && parent)
    end
    @group = nil
    @children = nil
    @points = nil
    @parent = nil
    @depth = nil
    @childId = nil
    @bbox = nil
  end

  def isLeaf?
    children.nil?
  end

  # Fetch the node who owns a point equal to p.
  # Returns the point node if found, else nil.
  def nodeForPoint(point)
    node = deepestNodeContainingPoint(point) 
    return nil if !node.points
    node.points.each {|p| return node if p == point }
    nil
  end

  def findById(id)
    return @points.find {|p| p.id == id} if @points
  end

  def deleteById(id, builder = nil)
    raise StandardError if !@points
    i = @points.find_index {|p| p.id == id}
    return false if !i

    builder.destroyPrimitive(@points[i]) if builder
    @points.delete_at(i)
    @points = nil if @points.empty?
    node = self
    while (node)
      if (!node.points && node.isLeaf? && node.parent)
        node.parent.deleteChild(node.childId, builder) 
        p = node.parent  
        node.parent = nil
        node = p
      else
        node = nil
      end
    end
    true
  end

  # Delete a point by value. Returns the deleted point if it exists, else nil.
  def deletePoint(p, builder)
    node = deepestNodeContainingPoint(p)
    result = nil
    if (node.points)
      result = node.points.delete(p)
      node.points = nil if node.points.empty?
    end
    builder.destroyPrimitive(result) if (builder && result)
    while (node)
      if (!node.points && node.isLeaf? && node.parent)
        node.parent.deleteChild(node.childId, builder) 
        p = node.parent  
        node.parent = nil
        node = p
      else
        node = nil
      end
    end
    result
  end

  def deleteChild(childId, builder)
    if (@children && @children[childId])
      builder.destroyGroup(@children[childId].group) if builder
      @children[childId] = nil
      @children = nil unless 
        (@children[0] || @children[1] || @children[2] || @children[3])
    end
  end

  def buildPrimitive(p, heap, builder)
    builder.buildPrimitive(group, p) if builder
    heap[p.id] = self
  end

  # Add a single point to the tree, starting at this node.
  def addPoint(p,maxDepth,heap,builder)
    axiom = deepestNodeContainingPoint(p)
    if (!axiom.bbox.containsPoint?(p))
      #points outside the root bounds require either a) rebuild the tree
      #b) build the tree bottom up, recursively adding new root nodes.  a is 
      #slow, but b can invalidate the maxDepth invariant... for now, have the 
      #accelerator grow a 'large enough' root to accomodate future points added.
      return false
    end
    if (axiom.isLeaf?)
      axiom.points = [] if !axiom.points
      axiom.points << p
      if (axiom.points.size > QuadTreeAccelerator::maxPointsPerNode && 
          depth < maxDepth)
        axiom.branch(maxDepth, heap, builder)
      else
        axiom.buildPrimitive(p, heap, builder)
      end
    else
      # Internal node, with partial child nodes which are tree leaves.  By 
      # definition, a child / leaf doesn't exist matching the new point.
      QuadBox.subdivideBBox(axiom.bbox).each_with_index {|leafBBox,i|
        if (leafBBox.containsPoint?(p))
          raise StandardError if axiom.children[i]
          axiom.setChild(i, QuadTreeNode.new([p], leafBBox, i, axiom, 
                                             maxDepth, heap, builder))
          return true
        end
      }
      # Impossible (?) case of intersecting a node but not its children.
      raise StandardError 
    end
    true
  end

  # Branch new children and push our points into them.
  def branch(maxDepth, heap, builder)
    raise ArgumentError if !@points
    childBoxes = QuadBox.subdivideBBox(bbox)
    pointsByQuad = [[],[],[],[]]

    # Ensure points are binned to a single child node. 
    # Alernative is mapping p_xy->childId.
    @points.each {|p|
      (0..3).each {|i|
        if childBoxes[i].containsPoint?(p)
          pointsByQuad[i] << p 
          break
        end
      }
    }
    @points = nil
    @children = [nil,nil,nil,nil]
    for i in (0..3)
      unless (pointsByQuad[i].empty?)
        @children[i] = QuadTreeNode.new(pointsByQuad[i], childBoxes[i], i,
                                        self, maxDepth, heap, builder) 
        pointsByQuad[i] = nil
      end
    end
  end

  # Local node name
  def name
    "(#{depth},#{childId})"
  end

  # Traverse nodes up to root.  Visited nodes are push to nodes array.
  def parentTraversal(nodes)
    nodes << self
    p = parent
    while (p)
      nodes << p
      p = p.parent
    end
  end

  # String representation of path from root
  def path
    nodes = []
    parentTraversal(nodes)
    nodes.reverse_each.map {|n| n.childId}.join('/')
  end

  def to_s
    depthPrefix = "    " * depth
    report = "#{depthPrefix}(#{depth},#{bbox},[#{points.join(',') if points}])\n"
    if (children)
      report << "#{depthPrefix}  SW\n#{children[SW]}" if children[SW]
      report << "#{depthPrefix}  SE\n#{children[SE]}" if children[SE]
      report << "#{depthPrefix}  NE\n#{children[NE]}" if children[NE]
      report << "#{depthPrefix}  NW\n#{children[NW]}" if children[NW]
    end
    report
  end

  # Debugging routine to ensure quadtree invariants are met.
  def invariantsOk?
    nodeTraversal {|n| 
      # When all children are empty, children must be nil.
      if (n.children && !(n.children[0] || n.children[1] || 
                             n.children[2] || n.children[3]))
        return false
      end
      # Validate members
      if (!n.bbox || !n.childId || n.childId < 0 || n.childId > 3 || n.depth < 0)
        return n
      end
      if (n.parent && n.parent.depth != n.depth-1)
        return n
      end
      # Node is a leaf iff it contains points.
      if (n.points && !n.isLeaf?)
        return n
      end
      # A leaf's points must be nil if empty.
      if (n.points && n.points.empty?)
        return n
      end

      # A leaf's points must be contained within its extent.
      if (n.points && n.points.find{|p| !n.bbox.containsPoint?(p) })
        return n
      end

      # Node must match the respective parent's child unless root
      if (n.parent && n.parent.children[n.childId] != n)
        return n
      end
     
      #todo - should really check containment, not intersection
      if (n.parent && !(floatEquals(2.0*n.bbox.size.x, n.parent.bbox.size.x) &&
          floatEquals(2.0*n.bbox.size.y, n.parent.bbox.size.y) &&
          floatEquals(n.bbox.size.z, n.parent.bbox.size.z) &&
          n.bbox.intersectsBBox?(n.parent.bbox)))
        return n
      end
    }
    nil
  end

  def findByPosition(position,radius)
    node = deepestNodeContainingPoint(position)
    if (node)
      x0, y0 = position.x - radius, position.y - radius
      x1, y1 = position.x + radius, position.y + radius
      if (node.points)
        return node.points.find {|p| 
          p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1 
        }
      end
    end
    nil
  end

  # Depth-traversal of nodes
  def eachNode(&block)
    yield self
    children.each {|c| 
      if c
        c.eachNode(&block)
      end
    } if children
  end

  def eachPoint(&block)
    @points.each {|p| yield p} if @points
    children.each {|c| 
      if c
        c.eachPoint(&block)
      end
    } if children
  end
  protected

  def setChild(childId, subTree)
    raise ArgumentError if childId > NW
    @children = [nil,nil,nil,nil] if !children
    @children[childId]  = subTree
  end

  # Helper method to fetch the deepest node in the tree whose
  # extent overlaps p.  The point found shall be either
  # a) a leaf node
  # b) an internal with a nil child corresponding to p's extent.
  def deepestNodeContainingPoint(p)
    children.each_with_index { |c, i|
      if (c && c.bbox.containsPoint?(p))
        return c.deepestNodeContainingPoint(p)
      end
    } if children
    return self
  end

  private
end

class QuadTreeAccelerator
  @@maxPointsPerNode = 1
  attr_reader :tree
  attr_reader :maxDepth
  attr_reader :builder
  attr_reader :heap

  # Initialize the Accelerator 
  # Supplied points must expose methods for:
  #   'id' - unique point identifier
  #   'x', 'y' and 'z' - whose values correspond to some orthogonal basis. 
  # maxDepth is the maximum tree depth, with root at depth = 0.
  # bounds is an optional user-defined bounding box. A BBox > BBox(points) 
  # allows growth of the QuadTree without restructuring, but may reduce
  # performance.  A BBox < BBox(points), is resized to fit.
  # builder provides callbacks for construction/destruction of nodes/primitives.
  # A builder must expose an interface of:
  #   buildPrimitive - called when a primitive must be built.
  #   buildGroup - called when a group describing the node must be built.
  #   destroyPrimitive - called when a primitive must be destroyed.%
  #   destroyGroup - called when a group must be destroyed.
  def initialize(points, builder = nil, maxDepth = nil, bounds = nil)
    raise ArgumentError if (!bounds && (!points || points.class != Array))
    raise ArgumentError if (!bounds && points.size < 2)
    raise ArgumentError if (maxDepth && maxDepth < 0)

    @builder = builder

    bounds = BBox.new(points[0], points[1]) if !bounds
    @maxDepth = maxDepth ? maxDepth : depthHeuristic(points.size)
    build(points, bounds)
#    raise StandardError if @tree.invariantsOk?
  end

  def build(points, bounds)
    points.each {|p| bounds.unionPoint(p)} if points
    @heap = {}
    @tree = QuadTreeNode.new(points, bounds, 0, nil, @maxDepth, heap, builder)  
  end

  # Destroy the tree, allowing user-builders to cleanup.
  def destroy
    @tree.destroy(builder)
    @tree = nil
    @heap = nil
    @builder = nil
    @maxDepth = nil
  end

  def self.maxPointsPerNode
    @@maxPointsPerNode
  end

  def self.maxPointsPerNode=(v)
    raise ArgumentError if v < 1
    @@maxPointsPerNode = v
  end

  # Add a single point to the tree.
  def addPoint(p)
    if (!p)
      $stderr.puts "Quadtree ignoring nil point added"
      return
    end
    if (!@tree.addPoint(p, @maxDepth, @heap, @builder))
      bounds = @tree.bbox
      points = [p]
      @tree.eachPoint {|nextPoint| points << nextPoint}
      @tree.destroy(builder)
      heuristic = depthHeuristic(points.size)
      @maxDepth = maxDepth > heuristic ? maxDepth : heuristic;
      build(points, bounds)
    end
#    raise StandardError if @tree.invariantsOk?
  end

  def deleteById(id)
    raise ArgumentError if !id
    if (heap[id])
      if (heap[id].deleteById(id, @builder))
        heap.delete(id)
        return true
      end
      # A point must always be successfully deleted if found in the heap.
      raise StandardError
    end
    false
  end

  def findById(id)
    if  (id && heap[id])
      return heap[id].findById(id)  
    end
    return nil
  end

  def findByPosition(x,y,radius)
    position = Point3.new(x,y,@tree.bbox.centre.z)
    found = @tree.findByPosition(position, radius)
    found
  end

  # Delete a single point from the tree matching the value of p.
  def deletePoint(p)
    @tree.deletePoint(p, @builder)
  end

  def to_s
    @tree.to_s
  end

  def eachPoint (&block)
    @tree.eachPoint(&block)
  end

  private
  def depthHeuristic(numPoints)
    (Math.log2(4 * numPoints / @@maxPointsPerNode) / 2.0).ceil 
  end
end

