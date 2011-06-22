#
#  point.rb
#  quad-tree-accelerator
#
#  Created by Daniel Grigg on 22/06/11.
#  Copyright 2011 Daniel Grigg. All rights reserved.
#

def floatEquals(a, b, eps = 4E-5)
  return ((a - b).abs < eps)
end

# Low-level 3d point class.
class Point3
  attr_accessor :x
  attr_accessor :y
  attr_accessor :z

  def initialize(x, y, z)
    @x, @y, @z = x, y, z
  end

  #We test exact values here, we should be adding
  #a tolerance :)
  def eql?(q)
    x == q.x && y == q.y && z == q.z
  end

  def ==(q)
    x == q.x && y == q.y && z == q.z
  end

  def to_s
    "[#{x},#{y},#{z}]"
  end
end


class PointOps
  def self.min(a, b)
    Point3.new(a.x < b.x ? a.x : b.x, 
               a.y < b.y ? a.y : b.y,
               a.z < b.z ? a.z : b.z)
  end
  def self.max(a, b)
    Point3.new(a.x < b.x ? b.x : a.x, 
               a.y < b.y ? b.y : a.y,
               a.z < b.z ? b.z : a.z)
  end
end

# A Point3 ready for interactive quad-tree usage as it expects
# an id field for lookups etc.  Not really intended for production.
class UniquePoint3 < Point3
  attr_reader :id
  @@nextId = 0
  def initialize(x, y, z)
    @id = UniquePoint3.nextId
    super(x,y,z)
  end

  def self.nextId
    @@nextId += 1
    @@nextId
  end

  def to_s
    "(#{id},#{super})"
    super
  end
end

