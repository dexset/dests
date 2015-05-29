/++ DES TestSuite
 +
 + Minimal test suite for easy unittesting
 +/
module des.ts;

import std.traits;
import std.typetuple;
import std.math;

import std.stdio;
import std.string;
import std.exception;
import std.conv : to;
import std.format : FormatException;
import core.exception : AssertError;

private
{
    debug enum __DEBUG__ = true;
    else  enum __DEBUG__ = false;

    version(unittest) enum __UNITTEST__ = true;
    else              enum __UNITTEST__ = false;

    version( des_ts_always_assert )
        enum __ALWAYS_ASSERT__ = true;
    else
    {
        enum __ALWAYS_ASSERT__ = false;

        static if( !__DEBUG__ && !__UNITTEST__ )
            pragma(msg, "## Warning: des.ts not use asserts, use 'version=des_ts_always_assert'");
    }

    enum __USE_ASSERT__ = __UNITTEST__ || __DEBUG__ || __ALWAYS_ASSERT__;
}

/// check equals `a` and `b`
bool eq(A,B)( in A a, in B b ) pure
{
    static if( allSatisfy!(isLikeArray,A,B) )
    {
        if( a.length != b.length ) return false;

        foreach( i; 0 .. a.length )
            if( !eq( a[i], b[i] ) ) return false;

        return true;
    }
    else static if( isSomeObject!A && isSomeObject!B ) return a is b;
    else static if( allSatisfy!(isNumeric,A,B) && anySatisfy!(isFloatingPoint,A,B) )
    {
        static if( isFloatingPoint!A && isFloatingPoint!B )
            auto epsilon = fmax( A.epsilon, B.epsilon );
        else static if( isFloatingPoint!A ) auto epsilon = A.epsilon;
        else static if( isFloatingPoint!B ) auto epsilon = B.epsilon;
        else static assert(0, "WTF? not A nor B isn't floating point" );

        return abs( a - b ) < epsilon;
    }
    else return a == b;
}

///
unittest
{
    assert(  eq( 1, 1.0 ) );
    assert(  eq( "hello", "hello"w ) );
    assert( !eq( cast(void[])"hello", cast(void[])"hello"w ) );
    assert(  eq( cast(void[])"hello", cast(void[])"hello" ) );
    assert(  eq( cast(void[])"hello", "hello" ) );
    assert( !eq( cast(void[])"hello", "hello"w ) );
    assert(  eq( [[1,2],[3,4]], [[1.0f,2],[3.0f,4]] ) );
    assert( !eq( [[1,2],[3,4]], [[1.1f,2],[3.0f,4]] ) );
    assert( !eq( [[1,2],[3,4]], [[1.0f,2],[3.0f]] ) );
    assert(  eq( [1,2,3], [1.0,2,3] ) );
    assert(  eq( [1.0f,2,3], [1.0,2,3] ) );
    assert(  eq( [1,2,3], [1,2,3] ) );
    assert( !eq( [1.0000001,2,3], [1,2,3] ) );
    assert(  eq( ["hello","world"], ["hello","world"] ) );
    assert( !eq( "hello", [1,2,3] ) );
    static assert( !__traits(compiles, eq(["hello"],1)) );
    static assert( !__traits(compiles, eq(["hello"],[1,2,3])) );
}

/++ check equals `a` and `b` approx with epsilon
 + Params:
 +
 + a = first value
 + b = second value
 + eps = numeric epsilon
 +/
bool eq_approx(A,B,E)( in A a, in B b, in E eps ) pure
    if( isNumeric!E && ( allSatisfy!(isNumeric,A,B) || allSatisfy!(isLikeArray,A,B) ) )
{
    static if( allSatisfy!(isLikeArray,A,B) )
    {
        if( a.length != b.length ) return false;
        foreach( i; 0 .. a.length )
            if( !eq_approx( a[i], b[i], eps ) ) return false;
        return true;
    }
    else return abs( a - b ) < eps;
}

///
unittest
{
    assert(  eq_approx( [1.1f,2,3], [1,2,3], 0.2 ) );
    assert( !eq_approx( [1.1f,2,3], [1,2,3], 0.1 ) );
    assert( !eq_approx( [1.0f,2], [1,2,3], 1 ) );
}

private template isLikeArray(T)
{
    enum isLikeArray = !is( Unqual!T == void[] ) &&
                          is( typeof(T.init[0]) ) &&
                         !is( Unqual!(typeof(T.init[0])) == void ) &&
                          is( typeof( T.init.length ) == size_t );
}

unittest
{
    static assert(  isLikeArray!(int[]) );
    static assert(  isLikeArray!(float[]) );
    static assert(  isLikeArray!(string) );
    static assert( !isLikeArray!int );
    static assert( !isLikeArray!float );
    static assert( !isLikeArray!(immutable(void)[]) );
}

private template isSomeObject(T)
{
    enum isSomeObject = is( T == class ) || is( T == interface );
}

/++ try call delegate
 +
 + Params:
 +
 + fnc = called delegate
 + throw_unexpected = if `true` when catch exception with type != `E` throw it out, if `false` ignore it
 +
 + Returns:
 + `true` if is catched exception of type `E`, `false` otherwise
 +/
bool mustExcept(E:Throwable=Exception)( void delegate() fnc, bool throw_unexpected=true )
in { assert( fnc !is null, "delegate is null" ); } body
{
    static if( !is( E == Throwable ) )
    {
        try fnc();
        catch( E e ) return true;
        catch( Throwable t )
            if( throw_unexpected ) throw t;
        return false;
    }
    else
    {
        try fnc();
        catch( Throwable t ) return true;
        return false;
    }
}

///
unittest
{
    assert(  mustExcept!Exception( { throw new Exception("test"); } ) );
    assert( !mustExcept!Exception( { throw new Throwable("test"); }, false ) );
    assert(  mustExcept( { throw new Exception("test"); } ) );
    assert( !mustExcept( { throw new Throwable("test"); }, false ) );
    assert(  mustExcept!Throwable( { throw new Exception("test"); } ) );
    assert(  mustExcept!Throwable( { throw new Throwable("test"); } ) );
    assert( !mustExcept!Exception({ auto a = 4; }) );
}

///
unittest
{
    static class A {}
    static assert( !__traits(compiles, mustExcept!A({})) );

    static class TestExceptionA : Exception
    { this() @safe pure nothrow { super( "" ); } }
    static class TestExceptionB : Exception
    { this() @safe pure nothrow { super( "" ); } }
    static class TestExceptionC : TestExceptionA
    { this() @safe pure nothrow { super(); } }

    assert(  mustExcept!Exception({ throw new TestExceptionA; }) );
    assert(  mustExcept!Exception({ throw new TestExceptionB; }) );

    assert(  mustExcept!TestExceptionA({ throw new TestExceptionA; }) );
    assert(  mustExcept!TestExceptionA({ throw new TestExceptionC; }) );
    assert(  mustExcept!TestExceptionB({ throw new TestExceptionB; }) );

    assert( !mustExcept!TestExceptionB( { throw new TestExceptionA; }, false ) );
    assert( !mustExcept!TestExceptionA( { throw new TestExceptionB; }, false ) );

    auto test_b_catched = false;
    try mustExcept!TestExceptionA({ throw new TestExceptionB; });
    catch( TestExceptionB ) test_b_catched = true;
    assert( test_b_catched );
}

/++ throws `AssertError` if `!eq( a, b )`
 +
 + Params:
 +
 + a = first value
 + b = second value
 + fmt = error message format, must have two string places `'%s'` for `a` and `b`
 +/
void assertEq(A,B,string file=__FILE__,size_t line=__LINE__)( in A a, in B b, lazy string fmt=null )
if( is( typeof( eq(a,b) ) ) )
{
    static if( __USE_ASSERT__ )
        enforce( eq( a, b ), newError( file, line,
                    ( fmt.length > 0 ? fmt : "assertEq fails: %s != %s" ),
                    toStringForce(a), toStringForce(b) ) );
}

///
unittest
{
    assert(  mustExcept!AssertError({ assertEq( 1, 2 ); }) );
    assert(  mustExcept!AssertError({ assertEq( [1,2], [2,3] ); }) );
    assert( !mustExcept!AssertError({ assertEq( [1,2], [1,2] ); }) );
}

/++ throws `AssertError` if `eq( a, b )`
 +
 + Params:
 +
 + a = first value
 + b = second value
 + fmt = error message format, must have two string places `'%s'` for `a` and `b`
 +/
void assertNotEq(A,B,string file=__FILE__,size_t line=__LINE__)( in A a, in B b, lazy string fmt=null )
if( is( typeof( eq(a,b) ) ) )
{
    static if( __USE_ASSERT__ )
        enforce( !eq( a, b ), newError( file, line,
                    ( fmt.length > 0 ? fmt : "assertNotEq fails: %s == %s" ),
                    toStringForce(a), toStringForce(b) ) );
}

/++ throws `AssertError` if `a !is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message format, must have one string place `'%s'` for `a`
 +/
void assertNull(A,string file=__FILE__,size_t line=__LINE__)( in A a, lazy string fmt=null )
{
    static if( __USE_ASSERT__ )
        enforce( a is null, newError( file, line,
                    ( fmt.length > 0 ? fmt : "assertNull fails: %s !is null" ),
                    toStringForce(a) ) );
}

/++ throws `AssertError` if `a is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message format, must have one string place `'%s'` for `a`
 +/
void assertNotNull(A,string file=__FILE__,size_t line=__LINE__)( in A a, lazy string fmt=null )
{
    static if( __USE_ASSERT__ )
        enforce( a !is null, newError( file, line,
                    ( fmt.length > 0 ? fmt : "assertNotNull fails: %s is null" ),
                    toStringForce(a) ) );
}

/+ not pure because using stderr and toStringForce isn't pure +/
auto newError(Args...)( string file, size_t line, string fmt, Args args )
{
    string msg;
    try msg = format( fmt, args );
    catch( Exception )
    {
        stderr.writefln( "bad error format: '%s' (%s:%d)", fmt, file, line );
        msg = toStringForce( args );
    }
    return new AssertError( msg, file, line );
}

/+ not pure because to!string isn't pure +/
string toStringForce(Args...)( in Args args )
{
    static if( Args.length == 1 )
    {
        alias T = Args[0];
        auto val = args[0];

        static if( is( typeof( to!string( val ) )) )
            return to!string( val );
        else static if( isLikeArray!T )
        {
            string[] rr;
            foreach( i; 0 .. val.length )
                rr ~= toStringForce( val[i] );
            return "[ " ~ rr.join(", ") ~ " ]";
        }
        else static if( isSomeObject!T )
        {
            if( val is null ) return "null";
            else return to!string( cast(void*)val );
        }
        else static if( is( T == typeof(null) ) ) return null;
        else return val.stringof;
    }
    else return toStringForce( args[0] ) ~ ", " ~ toStringForce( args[1..$] );
}

unittest
{
    assert( eq( toStringForce([0,4]), "[0, 4]" ) );
    assert( eq( toStringForce(null), "null" ) );
    assert( eq( toStringForce(0), "0" ) );

    Object a = null;

    assert( eq( toStringForce(a), "null" ) );
    assert( eq( toStringForce(a,5), "null, 5" ) );

    assert( eq( to!string(new Object), "object.Object" ) );
    assert( !eq( toStringForce(new Object), "object.Object" ) );
}
