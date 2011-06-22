require 'bbox.rb'
require 'test/unit'

class TestBBox < Test::Unit::TestCase

  #All tests assume well behaved floating values for string comparisons...
  def testInitialize_nil_asserts
    assert_raise(ArgumentError) { BBox.new(nil,nil) } 
    assert_raise(ArgumentError) { BBox.new(Point3.new(0,0,0),nil) } 
    assert_raise(ArgumentError) { BBox.new(nil, Point3.new(0,0,0)) } 
  end

  def testInitialize_twoPoints_validBBox
    b = BBox.new(Point3.new(-2,-3,-4), Point3.new(5,6,7))
    assert_equal("[[-2,-3,-4],[5,6,7]]", b.to_s)
    b = BBox.new(Point3.new(20,-3,0), Point3.new(11,-8,7))
    assert_equal("[[11,-8,0],[20,-3,7]]", b.to_s)
  end

  def testInitialize_onePoint_validBBox
    b = BBox.new(Point3.new(3,4,5), Point3.new(3,4,5))
    assert_equal("[[3,4,5],[3,4,5]]", b.to_s)
  end

  def testUnionPoint_outsideBBox_expandedBBox
    b = BBox.new(Point3.new(0,0,0), Point3.new(3,4,5))
    b.unionPoint(Point3.new(6,8,9))
    assert_equal("[[0,0,0],[6,8,9]]", b.to_s)
    b.unionPoint(Point3.new(-1,-2,-0))
    assert_equal("[[-1,-2,0],[6,8,9]]", b.to_s)
  end

  def testUnionPoint_insideBBox_idempotent
    b = BBox.new(Point3.new(0,0,0), Point3.new(3,4,5))
    b.unionPoint(Point3.new(1,2,3))
    assert_equal("[[0,0,0],[3,4,5]]", b.to_s)
  end

  def testUnionBBox_nonOverlapping_union
    b = BBox.new(Point3.new(0,0,0), Point3.new(3,4,5))
    c = BBox.new(Point3.new(6,7,8), Point3.new(9,10,11))
    b.unionBBox(c)
    assert_equal("[[0,0,0],[9,10,11]]", b.to_s)
  end

  def testUnionBBox_overlapping_union
    b = BBox.new(Point3.new(-2,-3,-2), Point3.new(3,4,5))
    c = BBox.new(Point3.new(-1,-4,-2), Point3.new(4,3,0))
    b.unionBBox(c)
    assert_equal("[[-2,-4,-2],[4,4,5]]", b.to_s)
  end

  def testCentre_unitBBox_isCentre
    b = BBox.new(Point3.new(-1,-1,-1), Point3.new(1,1,1))
    assert_equal("[0.0,0.0,0.0]", b.centre.to_s)
  end

  def testCentre_random_isCentre
    b = BBox.new(Point3.new(-7,12,15), Point3.new(-3,30,19))
    assert_equal("[-5.0,21.0,17.0]", b.centre.to_s)
  end

  def testSize_random_isSize
    b = BBox.new(Point3.new(-7.0,12.0,15.0), Point3.new(-3.0,30.0,19.0))
    assert_equal("[4.0,18.0,4.0]", b.size.to_s)
  end

  def testScale_scaleByOne_idempotent
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    s = b.scale(1,1,1)
    assert_equal("[[0.0,0.0,0.0],[1.0,1.0,1.0]]", s.to_s)
  end

  def testScale_unitScale_scaled
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    s = b.scale(0.5,2.0,3.0)
    assert_equal("[[0.25,-0.5,-1.0],[0.75,1.5,2.0]]", s.to_s)
  end

  def testContainsPoint_insideBBox_true
    b = BBox.new(Point3.new(2,3,4), Point3.new(3,4,5))
    assert_equal(true, b.containsPoint?(Point3.new(2.5, 3.2, 4.1)))
  end

  def testContainsPoint_outsideBBox_false
    b = BBox.new(Point3.new(0,0,0), Point3.new(3,4,5))
    assert_equal(false, b.containsPoint?(Point3.new(-0.1, 0, 0)))
  end

  def testContainsPoint_surfaceOfBBox_false
    b = BBox.new(Point3.new(0,0,0), Point3.new(4,4,4))
    assert_equal(true, b.containsPoint?(Point3.new(2, 2, 0)))
  end

  def testIntersectsBBox_outside_false
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    c = BBox.new(Point3.new(2,2,2), Point3.new(3,3,3))
    assert_equal(false, b.intersectsBBox?(c))
  end

  def testIntersectsBBox_inside_true
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    c = BBox.new(Point3.new(0.2,0.3,0.4), Point3.new(0.5,0.6,0.7))
    assert_equal(true, b.intersectsBBox?(c))
  end

  def testIntersectsBBox_overlaps_true
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    c = BBox.new(Point3.new(0.5,0.5,0.0), Point3.new(1.5,1.5,0.5))
    assert_equal(true, b.intersectsBBox?(c))
  end
  def testIntersectsBBox_surfaceOverlaps_true
    b = BBox.new(Point3.new(0,0,0), Point3.new(1,1,1))
    c = BBox.new(Point3.new(0.5,0.5,0.0), Point3.new(0.9,0.9,0.0))
    assert_equal(true, b.intersectsBBox?(c))
  end
end
