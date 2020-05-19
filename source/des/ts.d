/++ DES TestSuite
 +
 + Minimal test suite for easy unittesting
 +/
module des.ts;

public import std.exception;

import std.traits;
import std.meta;
import std.math;
import std.range;
import std.uni;
import std.string;
import std.stdio : stderr;
import std.conv : to;

import core.exception : AssertError;

/// check equals `a` and `b`
bool eq(A,B)( A a, B b )
{
    alias isNum = std.traits.isNumeric;
    static if( allSatisfy!(isElementArray,A,B) )
    {
        if( a.length != b.length ) return false;
        foreach( i; 0 .. a.length )
            if( !eq( a[i], b[i] ) ) return false;
        return true;
    }
    else static if( allSatisfy!(isSomeString,A,B) )
    {
        if( a.walkLength != b.walkLength ) return false;
        foreach( x,y; lockstep( a.byGrapheme, b.byGrapheme ) )
            if( x != y ) return false;
        return true;
    }
    else static if( isSomeObject!A && isSomeObject!B ) return a is b;
    else static if( allSatisfy!(isNum,A,B) && anySatisfy!(isFloatingPoint,A,B) )
    {
        static if( isFloatingPoint!A && isFloatingPoint!B )
            auto epsilon = fmax( A.epsilon, B.epsilon );
        else static if( isFloatingPoint!A ) auto epsilon = A.epsilon;
        else static if( isFloatingPoint!B ) auto epsilon = B.epsilon;
        else static assert(0, "WTF? not A nor B isn't floating point" );

        return abs( a - b ) < epsilon;
    }
    else static if( is(typeof(a==b)) ) return a == b;
    else static assert( 0, format( "uncompatible types '%s' and '%s'", nameOf!A, nameOf!B ) );
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
bool eq_approx(A,B,E)( A a, B b, E eps )
    if( isNumeric!E )
{
    static if( allSatisfy!(isElementArray,A,B) )
    {
        if( a.length != b.length ) return false;
        foreach( i; 0 .. a.length )
            if( !eq_approx( a[i], b[i], eps ) ) return false;
        return true;
    }
    else static if( allSatisfy!(isNumeric,A,B) ) return abs( a - b ) < eps;
    else static assert( 0, format( "uncompatible types '%s' and '%s'", nameOf!A, nameOf!B ) );
}

///
unittest
{
    assert(  eq_approx( [1.1f,2,3], [1,2,3], 0.2 ) );
    assert( !eq_approx( [1.1f,2,3], [1,2,3], 0.1 ) );
    assert( !eq_approx( [1.0f,2], [1,2,3], 1 ) );
    static assert( !__traits(compiles, eq_approx( [[1,2]], [1,2] )) );
}

/++
 +
 + Params:
 +
 + a = first value
 + b = second value
 + fmt = error message format, must have two string places `'%s'` for `a` and `b`
 +/
void assertEq(A,B)( A a, B b,
        string fmt="assertEq fails: %s != %s",
        string file=__FILE__, size_t line=__LINE__ )
{
    if( eq( a, b ) ) return;
    error( file, line, fmt, toStringForce(a), toStringForce(b) );
}

/++ throws `AssertError` if `eq( a, b )`
 +
 + Params:
 +
 + a = first value
 + b = second value
 + fmt = error message format, must have two string places `'%s'` for `a` and `b`
 +/
void assertNotEq(A,B)( A a, B b,
        lazy string fmt="assertNotEq fails: %s == %s",
        string file=__FILE__, size_t line=__LINE__ )
{
    if( !eq( a, b ) ) return;
    error( file, line, fmt, toStringForce(a), toStringForce(b) );
}

/++ throws `AssertError` if `a !is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message format, must have one string place `'%s'` for `a`
 +/
void assertNull(A)( A a,
        lazy string fmt="assertNull fails: %s !is null",
        string file=__FILE__, size_t line=__LINE__ )
{
    if( a is null ) return;
    error( file, line, fmt, toStringForce(a) );
}

/++ throws `AssertError` if `a is null`
 +
 + Params:
 +
 + a = value
 + fmt = error message (without format chars)
 +/
void assertNotNull(A)( A a,
        lazy string fmt="assertNotNull fails: value is null",
        string file=__FILE__, size_t line=__LINE__ )
{
    if( a !is null ) return;
    error( file, line, fmt );
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
void assertEqApprox(A,B,E)( A a, B b, E eps,
        lazy string fmt="assertEqApprox fails: %s != %s",
        string file=__FILE__, size_t line=__LINE__ )
{
    if( eq_approx( a, b, eps ) ) return;
    error( file, line, fmt, toStringForce(a), toStringForce(b) );
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
    static if( !( RANGETYPE == "[]" || RANGETYPE == "()" ||
                    RANGETYPE == "[)" || RANGETYPE == "(]" ) )
        static assert( 0, format( "range type must be one of '[]'," ~
                                "'()', '(]', '[)', not '%s'", RANGETYPE ) );

    enum op1 = RANGETYPE[0] == '[' ? "<=" : "<";
    enum op2 = RANGETYPE[1] == ']' ? "<=" : "<";

    mixin( format( q{
        if( min_value %s tested_value && tested_value %s max_value ) return;
        error( file, line, fmt, toStringForce(tested_value), format( "%s%%s, %%s%s", min_value, max_value ) );
        }, op1, op2, RANGETYPE[0], RANGETYPE[1] ) );
}

///
unittest
{
    assertInRange( 0, 1, 2 );
    assertInRange( 0, 0, 2 );
    assertInRange!"[]"( 0, 2, 2 );
    assertInRange!"(]"( 0.0f, 2, 2.0 );
}

void error(Args...)( string file, size_t line, string fmt, Args args )
{
    string msg;
    try msg = format( fmt, args );
    catch( Exception ) msg = "[FMTERR] " ~ toStringForce( args );
    throw new AssertError( msg, file, line );
}

/+ not pure because to!string isn't pure +/
private string toStringForce(Args...)( in Args args )
{
    static if( Args.length == 1 )
    {
        alias T = Args[0];
        auto val = args[0];

        static if( isSomeString!T )
            return "'" ~ to!string(val) ~ "'";
        else static if( is( typeof( to!string( val ) )) )
            return to!string( val );
        else static if( isElementArray!T )
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

    assert( eq( toStringForce("hello"), "'hello'" ) );

    Object a = null;

    assert( eq( toStringForce(a), "null" ) );
    assert( eq( toStringForce(a,5), "null, 5" ) );

    assert( eq( to!string(new Object), "object.Object" ) );
    assert( !eq( toStringForce(new Object), "object.Object" ) );
}

unittest
{
    static struct fMtr { float[][] data; alias data this; }
    static struct dMtr { double[][] data; alias data this; }

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
    static struct fMtr { float[][] data; alias data this; }
    static struct dMtr { double[][] data; alias data this; }

    auto a = fMtr( [[1,2,3],[2,3,4]] );
    assertEqApprox( a, [[1,2,3],[2,3,4]], float.epsilon );
    assertEqApprox( [[1,2,3],[2,3,4]], a, float.epsilon );
    auto b = fMtr( [[1,2,3],[2,3,4]] );
    assertEqApprox( a, b, float.epsilon );
    auto c = dMtr( [[1,2,3],[2,3,4]] );
    assertEqApprox( a, c, float.epsilon );
}

unittest
{
    static struct fVec { float[3] data; alias data this; }
    auto a = fVec([1,2,3]);
    assertEq( a, [1,2,3] );
    double[] b = [1,2,3];
    assertEq( a, b );
}

unittest
{
    static assert( !__traits(compiles, eq( "hello", 123 ) ) );
    static struct fVec { float[] data; alias data this; }
    auto a = fVec([32]);
    static assert( !__traits(compiles, eq( a, 123 ) ) );
}

private:

template nameOf(T)
{
    static if( __traits(compiles,typeid(T).name) )
        enum nameOf = typeid(T).name;
    else enum nameOf = T.stringof;
}

// not in des.stdx.traits for break dependencies
template isElementArray(R)
{
    enum isElementArray = is(typeof(
    (inout int = 0)
    {
        R r = R.init;
        auto e = r[0];
        static assert( hasLength!R );
        static assert( !isNarrowString!R );
    }));
}

unittest
{
    static assert(  isElementArray!(int[]) );
    static assert(  isElementArray!(int[3]) );
    static assert(  isElementArray!(float[]) );

    static struct Vec0
    {
        float[] data;
        alias data this;
    }
    static assert(  isElementArray!Vec0 );

    static struct Vec1 { float[] data; }
    static assert( !isElementArray!Vec1 );

    static assert( !isElementArray!(string) );
    static assert( !isElementArray!(wstring) );
    static assert( !isElementArray!int );
    static assert( !isElementArray!float );
    static assert( !isElementArray!(immutable(void)[]) );
}

template isSomeObject(T)
{ enum isSomeObject = is( T == class ) || is( T == interface ); }
