## D Extended Set (DES) test suite
[![Build Status](https://travis-ci.org/dexset/dests.svg?branch=master)](https://travis-ci.org/dexset/dests)
[![Join the chat at https://gitter.im/dexset/discussion](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/dexset/discussion)

some aux funcs for unittesting 
#### `eq` func Example:

```d
/+ using epsilon of second argument (double.epsilon)
 + for compare int and double
 + abs( 1 - 1.0 ) < double.epsilon
 +/
assert( eq( 1, 1.0 ) );

// ditto
assert( eq( [[1,2],[3,4]], [[1.0f,2],[3.0f,4]] ) );

// grapheme comparation
assert( eq( "hello", "hello"w ) );

// compile error: array of array can't be compared with int
static assert( !__traits(compiles, eq(["hello"],1)) );

/+ no compile error: char can be compared with int
 + but length of 'hello' not equals length of [1,2,3]
 +/
assert( !eq( "hello", [1,2,3] ) );

// approx comparation, only for numeric values
assert(  eq_approx( [1.1f,2,3], [1,2,3], 0.2 ) );
assert( !eq_approx( [1.1f,2,3], [1,2,3], 0.1 ) );
```

#### `assert` funcs Example:
```d
// use 'eq' func to compare values
assertEq( [1.0f,2.0f], [1,2] );

// throw AssertError with message 'assertNotEq fails: [1.0f, 2.0f] == [1, 2]'
assertNotEq( [1.0f,2.0f], [1,2] );

// throw AssertError with message 'fail compare: [1.0, 2.0] is not [1, 3]'
assertEq( [1.0f,2.0f], [1,3], "fail compare: %s is not %s" );

// use 'is' for comparation with null
assertNull( some_object );
assertNotNull( some_object );

// thowing exception assertion
assertExcept!MyException({ throw new MyException; });

// numeric in range assertion
assertInRange( 0, 1, 2 );
assertInRange( 0, 0, 2 );
assertExcept!AssertError({ assertInRange( 0, 2, 2 ); });
assertInRange!"[]"( 0, 2, 2 );
assertInRange!"(]"( 0.0f, 2, 2.0 );
```

To build doc use [harbored-mod](https://github.com/kiith-sa/harbored-mod)
