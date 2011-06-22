#
#  test_quad_tree_accelerator.rb
#  quad-tree-accelerator
#
#  Created by Daniel Grigg on 22/06/11.
#  Copyright 2011 Daniel Grigg. All rights reserved.

require 'quad_tree_accelerator.rb'
require 'test/unit'

# Simple test cases for the quad-tree-accelerator. 
# Old-skool unit tests amongst the BDD-ruby-mania but 
# they're a better match for low-level code.  Relying 
# on string representations is brittle though.
class TestQuadTreeAccelerator < Test::Unit::TestCase

  def setup
    QuadTreeAccelerator::maxPointsPerNode = 1
  end

  def testInitialize_noPointsNoBounds_asserts
    assert_raise(ArgumentError) { QuadTreeAccelerator.new(nil)}
    assert_raise(ArgumentError) { QuadTreeAccelerator.new([])}
  end

  def testInitialize_onePointNoBounds_asserts
    assert_raise(ArgumentError) { QuadTreeAccelerator.new(UniquePoint3.new(0,0,0))}
    assert_raise(ArgumentError) { QuadTreeAccelerator.new([UniquePoint3.new(0,0,0)])}
  end

  def testInitialize_zeroPointsBounded_validTree
    q = QuadTreeAccelerator.new(nil, nil, 8, 
                                BBox.new(UniquePoint3.new(0,0,0),UniquePoint3.new(5,5,5)))
    assert_equal("(0,[[0,0,0],[5,5,5]],[])\n", q.to_s)
  end
  
  def testInitialize_twoCornerPoints_validTree
    q = QuadTreeAccelerator.new([UniquePoint3.new(0,0,0), UniquePoint3.new(1,1,1)])
    assert_equal(
"(0,[[0,0,0],[1,1,1]],[])
  SW
    (1,[[0,0,0],[0.5,0.5,1]],[[0,0,0]])
  NE
    (1,[[0.5,0.5,0],[1,1,1]],[[1,1,1]])
", q.to_s)
  end

  def testInitialize_fourCornerPoints_validTree
    ps = [UniquePoint3.new(0,0,0),UniquePoint3.new(1,1,1),UniquePoint3.new(1,0,0),UniquePoint3.new(0,1,0)]
    q = QuadTreeAccelerator.new(ps)
  assert_equal(
"(0,[[0,0,0],[1,1,1]],[])
  SW
    (1,[[0,0,0],[0.5,0.5,1]],[[0,0,0]])
  SE
    (1,[[0.5,0,0],[1,0.5,1]],[[1,0,0]])
  NE
    (1,[[0.5,0.5,0],[1,1,1]],[[1,1,1]])
  NW
    (1,[[0,0.5,0],[0.5,1,1]],[[0,1,0]])
", q.to_s)
  end

  # Test a tree with two points in one quadrant, A and one point in another, B.
  # We expect A to partition it's space while B does not.
  def testInitialize_2SW_1NE_depth2
    ps = [UniquePoint3.new(0,0,0), UniquePoint3.new(3,3,0), UniquePoint3.new(8,8,8)]
    q = QuadTreeAccelerator.new(ps)
    assert_equal(
"(0,[[0,0,0],[8,8,8]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,8]],[])
      SW
        (2,[[0,0,0],[2.0,2.0,8]],[[0,0,0]])
      NE
        (2,[[2.0,2.0,0],[4.0,4.0,8]],[[3,3,0]])
  NE
    (1,[[4.0,4.0,0],[8,8,8]],[[8,8,8]])
", q.to_s)
  end

  #Place single points across depth1 nodes. We expect the correct
  #layout of nil vs single point nodes.
  def testInitialize_1SW_2NW_3NE_0SE_depth2
    ps = [UniquePoint3.new(0,0,0), UniquePoint3.new(1,7,2),
          UniquePoint3.new(3,5,2), UniquePoint3.new(5,7,2), UniquePoint3.new(5,5,2),
          UniquePoint3.new(7,5,2), UniquePoint3.new(8,8,8)]
    q = QuadTreeAccelerator.new(ps)
    assert_equal(
"(0,[[0,0,0],[8,8,8]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,8]],[[0,0,0]])
  NE
    (1,[[4.0,4.0,0],[8,8,8]],[])
      SW
        (2,[[4.0,4.0,0],[6.0,6.0,8]],[[5,5,2]])
      SE
        (2,[[6.0,4.0,0],[8,6.0,8]],[[7,5,2]])
      NE
        (2,[[6.0,6.0,0],[8,8,8]],[[8,8,8]])
      NW
        (2,[[4.0,6.0,0],[6.0,8,8]],[[5,7,2]])
  NW
    (1,[[0,4.0,0],[4.0,8,8]],[])
      SE
        (2,[[2.0,4.0,0],[4.0,6.0,8]],[[3,5,2]])
      NW
        (2,[[0,6.0,0],[2.0,8,8]],[[1,7,2]])
", q.to_s)
  end

  def testInitialize_maxDepth1_depth1
    ps  = [UniquePoint3.new(0,0,0), UniquePoint3.new(1,1,1), 
           UniquePoint3.new(2,2,2), UniquePoint3.new(3,3,3),
           UniquePoint3.new(3.5, 3.5, 3.5), UniquePoint3.new(8,8,0)]
    q = QuadTreeAccelerator.new(ps, nil, 1)
    assert_equal(
"(0,[[0,0,0],[8,8,3.5]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,3.5]],[[0,0,0],[1,1,1],[2,2,2],[3,3,3],[3.5,3.5,3.5]])
  NE
    (1,[[4.0,4.0,0],[8,8,3.5]],[[8,8,0]])
", q.to_s)
  end

  def testInitialize_nodeRecurse_depth4
    ps = [UniquePoint3.new(0,0,0), UniquePoint3.new(128,128,128),
          UniquePoint3.new(63,63,0), UniquePoint3.new(31,31,0),
          UniquePoint3.new(15,15,0), UniquePoint3.new(7,7,0),
          UniquePoint3.new(3,3,0), UniquePoint3.new(1.5,1.5,0)]
    q = QuadTreeAccelerator.new(ps, nil, 16)
    assert_equal(
"(0,[[0,0,0],[128,128,128]],[])
  SW
    (1,[[0,0,0],[64.0,64.0,128]],[])
      SW
        (2,[[0,0,0],[32.0,32.0,128]],[])
          SW
            (3,[[0,0,0],[16.0,16.0,128]],[])
              SW
                (4,[[0,0,0],[8.0,8.0,128]],[])
                  SW
                    (5,[[0,0,0],[4.0,4.0,128]],[])
                      SW
                        (6,[[0,0,0],[2.0,2.0,128]],[])
                          SW
                            (7,[[0,0,0],[1.0,1.0,128]],[[0,0,0]])
                          NE
                            (7,[[1.0,1.0,0],[2.0,2.0,128]],[[1.5,1.5,0]])
                      NE
                        (6,[[2.0,2.0,0],[4.0,4.0,128]],[[3,3,0]])
                  NE
                    (5,[[4.0,4.0,0],[8.0,8.0,128]],[[7,7,0]])
              NE
                (4,[[8.0,8.0,0],[16.0,16.0,128]],[[15,15,0]])
          NE
            (3,[[16.0,16.0,0],[32.0,32.0,128]],[[31,31,0]])
      NE
        (2,[[32.0,32.0,0],[64.0,64.0,128]],[[63,63,0]])
  NE
    (1,[[64.0,64.0,0],[128,128,128]],[[128,128,128]])
", q.to_s)
  end

  def testInitialize_maxPoints3_validTree
    ps = [UniquePoint3.new(0,0,0), UniquePoint3.new(128,128,128),
          UniquePoint3.new(30,2,0), UniquePoint3.new(30,30,0),
          UniquePoint3.new(34,34,0), UniquePoint3.new(62,34,0), UniquePoint3.new(34,62,0)]
    QuadTreeAccelerator.maxPointsPerNode = 3
    q = QuadTreeAccelerator.new(ps,nil,8)
    assert_equal(
"(0,[[0,0,0],[128,128,128]],[])
  SW
    (1,[[0,0,0],[64.0,64.0,128]],[])
      SW
        (2,[[0,0,0],[32.0,32.0,128]],[[0,0,0],[30,2,0],[30,30,0]])
      NE
        (2,[[32.0,32.0,0],[64.0,64.0,128]],[[34,34,0],[62,34,0],[34,62,0]])
  NE
    (1,[[64.0,64.0,0],[128,128,128]],[[128,128,128]])
", q.to_s)
  end

  #heavily dependent on tree initialization passing
  def testAddPoint_addOne_validTree
    ps = [UniquePoint3.new(-17,-31,47), UniquePoint3.new(12,-8,92)]
    q = QuadTreeAccelerator.new(ps, nil, 8)
    p = UniquePoint3.new(3, -10, 57)
    q.addPoint(p)
    r = QuadTreeAccelerator.new(ps + [p],nil, 8)
    assert_equal(q.to_s, r.to_s)
  end

  def testAddPoint_addMultiple_validTree
    # Ensure added points fall within our 1K^3 bounds.
    ps = [UniquePoint3.new(313,600,872),UniquePoint3.new(155,700,542),
          UniquePoint3.new(603,170,5),UniquePoint3.new(680,808,751),
          UniquePoint3.new(961,371,581),UniquePoint3.new(76,548,705),
          UniquePoint3.new(163,858,430),UniquePoint3.new(586,435,786),
          UniquePoint3.new(201,998,89),UniquePoint3.new(304,88,254),
          UniquePoint3.new(737,290,865),UniquePoint3.new(747,463,614),
          UniquePoint3.new(273,597,889),UniquePoint3.new(47,880,79),
          UniquePoint3.new(268,623,30),UniquePoint3.new(166,120,92),
          UniquePoint3.new(630,181,602),UniquePoint3.new(557,711,776),
          UniquePoint3.new(176,590,271),UniquePoint3.new(339,311,195),
          UniquePoint3.new(0,0,0),UniquePoint3.new(1000,1000,1000)]
    q = QuadTreeAccelerator.new(ps,nil,16)
    p2 = ps.pop 2
    r = QuadTreeAccelerator.new(p2,nil,16)
    ps.each {|p| r.addPoint(p)}
    assert_equal(q.to_s, r.to_s)
    nil
  end

  def testDeletePoint_rootNode_pointDeletedRootIntact
    q = QuadTreeAccelerator.new([UniquePoint3.new(2,2,2)], nil, 8, 
        BBox.new(UniquePoint3.new(0,0,0), UniquePoint3.new(5,5,5)))
    q.deletePoint(UniquePoint3.new(2,2,2))
    assert_equal("(0,[[0,0,0],[5,5,5]],[])\n", q.to_s)
  end
  
  def testDeletePoint_notAPoint_treeUnchanged
    QuadTreeAccelerator::maxPointsPerNode = 2
    ps = [UniquePoint3.new(1,1,1), UniquePoint3.new(3,3,3), UniquePoint3.new(6,6,6)]
    q = QuadTreeAccelerator.new(ps, 
                                nil, 8, 
                                BBox.new(UniquePoint3.new(0,0,0), UniquePoint3.new(8,8,8)))
    q.deletePoint(UniquePoint3.new(3.5,3.5,3.5))
    assert_equal(
"(0,[[0,0,0],[8,8,8]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,8]],[[1,1,1],[3,3,3]])
  NE
    (1,[[4.0,4.0,0],[8,8,8]],[[6,6,6]])
",q.to_s)
  end

  def testDeletePoint_multiplePointLeaf_pointDeletedTreeUnchanged
    QuadTreeAccelerator::maxPointsPerNode = 2
    ps = [UniquePoint3.new(1,1,1), UniquePoint3.new(3,3,3), UniquePoint3.new(6,6,6)]
    q = QuadTreeAccelerator.new(ps, 
                                nil, 8, 
                                BBox.new(UniquePoint3.new(0,0,0), UniquePoint3.new(8,8,8)))
    q.deletePoint(UniquePoint3.new(3,3,3))
    assert_equal(
"(0,[[0,0,0],[8,8,8]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,8]],[[1,1,1]])
  NE
    (1,[[4.0,4.0,0],[8,8,8]],[[6,6,6]])
",q.to_s)
  end

  def testDeletePoint_singlePointLeaf_leafDeleted
    QuadTreeAccelerator::maxPointsPerNode = 1
    ps = [UniquePoint3.new(1,1,1), UniquePoint3.new(3,3,3), UniquePoint3.new(6,6,6)]
    q = QuadTreeAccelerator.new(ps, 
                                nil, 8, 
                                BBox.new(UniquePoint3.new(0,0,0), UniquePoint3.new(8,8,8)))
    q.deletePoint(UniquePoint3.new(1,1,1))
    assert_equal(
"(0,[[0,0,0],[8,8,8]],[])
  SW
    (1,[[0,0,0],[4.0,4.0,8]],[])
      NE
        (2,[[2.0,2.0,0],[4.0,4.0,8]],[[3,3,3]])
  NE
    (1,[[4.0,4.0,0],[8,8,8]],[[6,6,6]])
", q.to_s)
  end
end

# Mmmm, what are missing...?
