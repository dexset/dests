/++ DES TestSuite
 +
 + Minimal test suite for easy unittesting
 +/
module des.ts;

import std.traits;
import std.typetuple;
import std.math;
import std.range;
import std.uni;
import std.string;
import std.exception;
import std.stdio : stderr;
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

private template isFiniteRandomAccessRange(T)
{ enum isFiniteRandomAccessRange = isRandomAccessRange!T && hasLength!T; }

unittest
{
    static assert(  isFiniteRandomAccessRange!(int[]) );
    static assert(  isFiniteRandomAccessRange!(float[]) );
    static assert( !isFiniteRandomAccessRange!(string) );
    static assert( !isFiniteRandomAccessRange!(wstring) );
    static assert( !isFiniteRandomAccessRange!int );
    static assert( !isFiniteRandomAccessRange!float );
    static assert( !isFiniteRandomAccessRange!(immutable(void)[]) );
}

/// check equals `a` and `b`
bool eq(A,B)( in A a, in B b )
{
    static if( allSatisfy!(isFiniteRandomAccessRange,A,B) )
    {
        if( a.length != b.length ) return false;
        foreach( i; 0 .. a.length )
            if( !eq( a[i], b[i] ) ) return false;
        return true;
    }
    else static if( allSatisfy!(isSomeString,A,B) )
    {
        if( walkLength(a) != walkLength(b) ) return false;
        foreach( g; zip( a.byGrapheme, b.byGrapheme ) )
            if( g[0] != g[1] ) return false;
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
    else static if( is(typeof(a==b)) ) return a == b;
    else static if( hasDataField!A && hasDataField!B )  return eq( a.data, b.data );
    else static if( hasDataField!A && !hasDataField!B ) return eq( a.data, b );
    else static if( !hasDataField!A && hasDataField!B ) return eq( a, b.data );
    else static assert( 0, format( "uncompatible types '%s' and '%s'", nameOf!A, nameOf!B ) );
}

private template nameOf(T)
{
    static if( __traits(compiles,typeid(T).name) )
        enum nameOf = typeid(T).name;
    else enum nameOf = T.stringof;
}

///
unittest
{
    assert(  eq( 1, 1.0 ) );
    assert(  eq( [1,2,3], [1.0,2,3] ) );
    assert(  eq( [1.0f,2,3], [1.0,2,3] ) );
    assert(  eq( [1,2,3], iota(1,4) ) );
    assert( !eq( [1.0000001,2,3], [1,2,3] ) );
    assert(  eq( [[1,2],[3,4]], [[1.0f,2],[3.0f,4]] ) );
    assert( !eq( [[1,2],[3,4]], [[1.1f,2],[3.0f,4]] ) );
    assert( !eq( [[1,2],[3,4]], [[1.0f,2],[3.0f]] ) );
}

///
unittest
{
    // string from Jonathan M Davis presentation
    auto s1 = `さいごの果実 / ミツバチと科学者`;
    auto s2 = `さいごの果実 / ミツバチと科学者`w;

    assert( s1.length != s2.length );
    assert( !eq( cast(void[])s1, cast(void[])s2 ) );
    assert( eq( s1, s2 ) );

    auto s1a = `さいごの果実`;
    auto s1b = `ミツバチと科学者`;

    auto s2a = `さいごの果実`w;
    auto s2b = `ミツバチと科学者`w;

    assert( eq( [s1a,s1b], [s2a,s2b] ) );

    assert( !eq( "hello", [1,2,3] ) );
    assert( eq( " "w, [ 32 ] ) );
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
    if( isNumeric!E && ( allSatisfy!(isNumeric,A,B) || allSatisfy!(isFiniteRandomAccessRange,A,B) ) )
{
    static if( allSatisfy!(isFiniteRandomAccessRange,A,B) )
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
    static assert( !__traits(compiles, eq_approx( [[1,2]], [1,2] )) );
}

private template isSomeObject(T)
{ enum isSomeObject = is( T == class ) || is( T == interface ); }

private template hasDataField(T)
{ enum hasDataField = is( typeof( T.init.data ) ); }

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
void assertEq(A,B,string file=__FILE__,size_t line=__LINE__)
             ( in A a, in B b, lazy string fmt="assertEq fails: %s != %s" )
{
    static if( __USE_ASSERT__ )
        enforce( eq( a, b ),
                newError( file, line, fmt, toStringForce(a), toStringForce(b) ) );
}

///
unittest
{
    assertEq( [1,2,3], iota(1,4) );
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
void assertNotEq(A,B,string file=__FILE__,size_t line=__LINE__)
                ( in A a, in B b, lazy string fmt="assertNotEq fails: %s == %s" )
{
    static if( __USE_ASSERT__ )
        enforce( !eq( a, b ),
                newError( file, line, fmt, toStringForce(a), toStringForce(b) ) );
}

/++ throws `AssertError` if `a !is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message format, must have one string place `'%s'` for `a`
 +/
void assertNull(A,string file=__FILE__,size_t line=__LINE__)
               ( in A a, lazy string fmt="assertNull fails: %s !is null" )
{
    static if( __USE_ASSERT__ )
        enforce( a is null, newError( file, line, fmt, toStringForce(a) ) );
}

/++ throws `AssertError` if `a is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message (without format chars)
 +/
void assertNotNull(A,string file=__FILE__,size_t line=__LINE__)
                  ( in A a, lazy string fmt="assertNotNull fails: value is null" )
{
    static if( __USE_ASSERT__ )
        enforce( a !is null, newError( file, line, fmt ) );
}

/++ throws `AssertError` if not except `E` or if except not `E`
 +
 + Params:
 +
 + fnc = delegate that must throw exception of type `E`
 +/
void assertExcept(E:Throwable=Exception, string file=__FILE__, size_t line=__LINE__)( void delegate() fnc )
{
    static if( __USE_ASSERT__ )
    {
        string result = "no exception";

        try if( mustExcept!E( fnc ) ) result = "success";
        catch( Throwable e ) result = format( "get unexpected '%s'", typeid(e).name );

        enforce( "success" == result, newError( file, line,
                    "assertExcept fails for delegate because %s", result ) );
    }
}

///
unittest
{
    static class TestExceptionA : Exception
    { this() pure nothrow @safe { super(""); } }

    static class TestExceptionB : Exception
    { this() pure nothrow @safe { super(""); } }

    string result = "no exception";

    try assertExcept!TestExceptionA({ throw new TestExceptionA; });
    catch( TestExceptionA ) result = "get test exception A";
    catch( Throwable e ) result = "get throwable: '" ~ typeid(e).name ~ "'";

    assertEq( "no exception", result );

    try assertExcept!TestExceptionB({ throw new TestExceptionA; });
    catch( TestExceptionA ) result = "get test exception A";
    catch( TestExceptionB ) result = "get test exception B";
    catch( AssertError ) result = "assert not pass";

    assertEq( "assert not pass", result );
}

/++ throws `AssertError` if `!eq_approx( a, b )`
 +
 + Params:
 +
 + a = first value
 + b = second value
 + eps = epsilon
 + fmt = error message format, must have two string places `'%s'` for `a` and `b`
 +/
void assertEqApprox(A,B,E,string file=__FILE__,size_t line=__LINE__)
                   ( in A a, in B b, in E eps, lazy string fmt="assertEqApprox fails: %s != %s" )
{
    static if( __USE_ASSERT__ )
        enforce( eq_approx( a, b, eps ),
                newError( file, line, fmt, toStringForce(a), toStringForce(b) ) );
}

///
unittest
{
    assert(  mustExcept!AssertError({ assertEqApprox( [1.0f,3.0f], [1.1f,3.0f], 0.05 ); }) );
    assert( !mustExcept!AssertError({ assertEqApprox( [1.0f,3.0f], [1.1f,3.0f], 0.5 ); }) );
}

/++ throws `AssertError` if tested value out of range
 +
 + for RANGETYPE allows values: `"[]"`, `"(]"`, `"[)"`, `"()"`
 +
 +/
void assertInRange( string RANGETYPE="[)",MIN,V,MAX,string file=__FILE__,size_t line=__LINE__ )
                  ( in MIN min_value, in V tested_value, in MAX max_value,
                    lazy string fmt="assertInRange fails: %s is out of %s" )
if( is(typeof(min_value<tested_value)) && is(typeof(tested_value<max_value)) )
{
    static if( __USE_ASSERT__ )
    {
        static if( !( RANGETYPE == "[]" || RANGETYPE == "()" ||
                      RANGETYPE == "[)" || RANGETYPE == "(]" ) )
            static assert( 0, format( "range type must be one of '[]'," ~
                                    "'()', '(]', '[)', not '%s'", RANGETYPE ) );

        enum op1 = RANGETYPE[0] == '[' ? "<=" : "<";
        enum op2 = RANGETYPE[1] == ']' ? "<=" : "<";

        mixin( format( q{
            enforce( min_value %s tested_value && tested_value %s max_value,
                    newError( file, line, fmt, toStringForce(tested_value),
                        format( "%s%%s, %%s%s", min_value, max_value ) ) );
            }, op1, op2, RANGETYPE[0], RANGETYPE[1] ) );
    }
}

///
unittest
{
    assertInRange( 0, 1, 2 );
    assertInRange( 0, 0, 2 );
    assertExcept!AssertError({ assertInRange( 0, 2, 2 ); });
    assertInRange!"[]"( 0, 2, 2 );
    assertInRange!"(]"( 0.0f, 2, 2.0 );
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
        else static if( isFiniteRandomAccessRange!T )
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

unittest
{
    static struct fMtr { float[][] data; }
    static struct dMtr { double[][] data; }

    auto a = fMtr( [[1,2,3],[2,3,4]] );
    assertEq( a, [[1,2,3],[2,3,4]] );
    assertEq( [[1,2,3],[2,3,4]], a );
    auto b = fMtr( [[1,2,3],[2,3,4]] );
    assertEq( a, b );
    auto c = dMtr( [[1,2,3],[2,3,4]] );
    assertEq( a, c );
}

unittest
{
    static struct fVec { float[3] data; }
    auto a = fVec([1,2,3]);
    assertEq( a, [1,2,3] );
    double[] b = [1,2,3];
    assertEq( a, b );
}

unittest
{
    static assert( !__traits(compiles, eq( "hello", 123 ) ) );
    static struct fVec { float[] data; }
    auto a = fVec([32]);
    static assert( !__traits(compiles, eq( a, 123 ) ) );
}
