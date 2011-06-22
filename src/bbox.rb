#
#  bbox.rb
#  quad-tree-accelerator
#
#  Created by Daniel Grigg on 22/06/11.
#  Copyright 2011 Daniel Grigg. All rights reserved.


require 'point.rb'

# Axis-aligned-bounding-box
class BBox
  attr_reader :min
  attr_reader :max

  def initialize(min, max)
    raise ArgumentError unless (min && max)
    @min = PointOps.min(min, max)
    @max = PointOps.max(min, max)
  end

  def unionPoint(p)
    @min = PointOps.min(@min, p)
    @max = PointOps.max(@max, p)
    self
  end

  def unionBBox(box)
    @min = PointOps.min(@min, box.min)
    @max = PointOps.max(@max, box.max)
    self
  end
  
  def centre
    Point3.new(0.5 * (min.x + max.x), 
               0.5 * (min.y + max.y),
               0.5 * (min.z + max.z))
  end

  def size
    Point3.new(max.x - min.x, max.y - min.y, max.z - min.z)
  end

  def scale(scaleX, scaleY, scaleZ)
    c = centre
    s = size
    scaleX *= 0.5; scaleY *= 0.5; scaleZ *= 0.5
    BBox.new(Point3.new(c.x-scaleX*s.x, c.y-scaleY*s.y, c.z-scaleZ*s.z),
             Point3.new(c.x+scaleX*s.x, c.y+scaleY*s.y, c.z+scaleZ*s.z))
  end

  def containsPoint?(p)
    p.x >= min.x && p.x <= max.x &&
    p.y >= min.y && p.y <= max.y &&
    p.z >= min.z && p.z <= max.z
  end

  def containsProjectedPoint?(p)
    p.x >= min.x && p.x <= max.x &&
    p.y >= min.y && p.y <= max.y
  end

  def intersectsBBox?(other)
    !((min.x > other.max.x || other.min.x > max.x ||
       min.y > other.max.y || other.min.y > max.y ||
       min.z > other.max.z || other.min.z > max.z))
  end

  def to_s
    "[#{min},#{max}]"
  end
end
