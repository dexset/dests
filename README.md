## D Extended Set (DES) test suite
[![Build Status](https://travis-ci.org/dexset/dests.svg?branch=master)](https://travis-ci.org/dexset/dests)
[![Join the chat at https://gitter.im/dexset/discussion](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/dexset/discussion)

some aux funcs for unittesting

#### `eq` func Example:

```d
/+ using epsilon of second argument (double.epsilon)
   for compare int and double
   abs( 1 - 1.0 ) < double.epsilon
 +/
assert(  eq( 1, 1.0 ) );

// ditto
assert(  eq( [[1,2],[3,4]], [[1.0f,2],[3.0f,4]] ) );

// character by character comparation
assert(  eq( "hello", "hello"w ) );

// for void[] simple byte by byte comparation
assert( !eq( cast(void[])"hello", cast(void[])"hello"w ) );

// compile error: array of array can't be compared with int
static assert( !__traits(compiles, eq(["hello"],1)) );

/+ no compile error: char can be compared with int
   but length of 'hello' not equals length of [1,2,3]
 +/
assert( !eq( "hello", [1,2,3] ) );

// approx comparation, only for numeric values
assert(  eq_approx( [1.1f,2,3], [1,2,3], 0.2 ) );
assert( !eq_approx( [1.1f,2,3], [1,2,3], 0.1 ) );
```

#### `mustExcept` func Example:

```d
static class TestExceptionA : Exception { this() @safe pure nothrow { super( "" ); } }
static class TestExceptionB : Exception { this() @safe pure nothrow { super( "" ); } }
static class TestExceptionC : TestExceptionA { this() @safe pure nothrow { super(); } }

// TestExceptionA is an Exception
assert(  mustExcept!Exception({ throw new TestExceptionA; }) );
// TestExceptionB is an Exception
assert(  mustExcept!Exception({ throw new TestExceptionB; }) );

assert(  mustExcept!TestExceptionA({ throw new TestExceptionA; }) );
// TestExceptionC is an TestExceptionA
assert(  mustExcept!TestExceptionA({ throw new TestExceptionC; }) );
assert(  mustExcept!TestExceptionB({ throw new TestExceptionB; }) );

// TestExceptionA is not a TestExceptionB
assert( !mustExcept!TestExceptionB( { throw new TestExceptionA; }, false ) );
// TestExceptionB is not a TestExceptionA
assert( !mustExcept!TestExceptionA( { throw new TestExceptionB; }, false ) );

auto test_b_catched = false;
try mustExcept!TestExceptionA({ throw new TestExceptionB; });
catch( TestExceptionB ) test_b_catched = true; // unexpectable exception in delegate
assert( test_b_catched );
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
```

Documentation orient to [harbored-mod](https://github.com/kiith-sa/harbored-mod)

to build doc:
```sh
cd path/to/dests
path/to/harbored-mod/bin/hmod
```
