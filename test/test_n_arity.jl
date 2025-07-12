using Test
using SymbolicRegression
using SymbolicRegression.ComposableExpressionModule:
    ComposableExpression, ValidVector, apply_operator
using DynamicExpressions: OperatorEnum, Node

@testset "N-arity operator support" begin
    # Test 3-ary operator support in ComposableExpression
    @testset "3-ary operators with ValidVector" begin
        # Test that apply_operator works with 3 arguments
        x = ValidVector([1.0, 2.0, 3.0], true)
        y = ValidVector([4.0, 5.0, 6.0], true)
        z = ValidVector([7.0, 8.0, 9.0], true)
        
        # Test with a simple 3-ary function
        three_sum(a, b, c) = a + b + c
        result = apply_operator(three_sum, x, y, z)
        
        @test result.valid == true
        @test result.x == [12.0, 15.0, 18.0]
        
        # Test with mixed ValidVector and Number arguments
        result2 = apply_operator(three_sum, x, y, 10.0)
        @test result2.valid == true
        @test result2.x == [15.0, 17.0, 19.0]
    end
    
    @testset "3-ary operators with function call syntax" begin
        # Test that 3-ary operators work with function call syntax
        x = ValidVector([1.0, 2.0], true)
        y = ValidVector([3.0, 4.0], true)
        z = ValidVector([5.0, 6.0], true)
        
        # Define a simple 3-ary function
        my_ternary(a, b, c) = a * b + c
        
        result = my_ternary(x, y, z)
        @test result.valid == true
        @test result.x == [8.0, 14.0]  # [1*3+5, 2*4+6]
        
        # Test with mixed arguments
        result2 = my_ternary(x, 2.0, z)
        @test result2.valid == true
        @test result2.x == [7.0, 10.0]  # [1*2+5, 2*2+6]
    end
    
    @testset "3-ary operators with invalid ValidVector" begin
        # Test that invalid ValidVector propagates correctly
        x = ValidVector([1.0, 2.0], true)
        y = ValidVector([3.0, 4.0], false)  # Invalid
        z = ValidVector([5.0, 6.0], true)
        
        my_ternary(a, b, c) = a * b + c
        result = my_ternary(x, y, z)
        @test result.valid == false
    end
    
    @testset "Common 3-ary operators" begin
        # Test with common 3-ary operators like ifelse
        x = ValidVector([1.0, 2.0, 3.0], true)
        y = ValidVector([4.0, 5.0, 6.0], true)
        z = ValidVector([7.0, 8.0, 9.0], true)
        
        # Test ifelse-like operator
        conditional_op(cond, a, b) = cond > 2.0 ? a : b
        result = conditional_op(x, y, z)
        @test result.valid == true
        @test result.x == [7.0, 8.0, 5.0]  # [cond=1.0→z, cond=2.0→z, cond=3.0→y]
    end
end