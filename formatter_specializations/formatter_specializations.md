---
title: "Formatter specializations"
document: XXX
date: today
audience: LEWG
author:
    - name: Mark de Wever
      email: <koraq@xs4all.nl>
toc: true
---

# Introduction

C++20 introduced `std::format` and in C++23 several improvements were made,
like [@P2286R8] and [@P2693R1]. Although some parts of the standard are formattable that do not have streaming support, the opposite is also true. Some types can be streamed, but not formatted. This paper looks at the parts that are not formattable and offers a solution of some of these parts. Other parts will be out of the scope of this paper, but are identified.


Some parts of the Standard library are not formattable
yet. This paper looks at the formattable state of the Standard library and
proposes formatter specializations for some of the missing parts.

# Motivation

The addition of `std::format` and `std::print` are a huge step forward for
formatting and printing objects in C++. Unfortunately for some types in the
Standard library users still need to use the stream operators to format the
output. A part of these issues have been identified in [@P1636R2] and had
proposed solutions. Unfortunately the author of the paper can no longer be
reached. (I reached out to the author and I know other committed members have
tried to.) Parts of the design of the paper are approved, but never made it
into the standard.







[@P1636R2] proposed to add formatter specializations to the Standard library.
The proposal has received positive feedback, but is waiting on a revision.
Unfortunately the author of the paper seems to be MIA.

This paper takes a look at the current state of formatter specializations in
the Standard library and proposes a new set of specializations. Filling all the
gaps would result in a large paper with a lot of open design questions, instead
the paper focusses on a subset of the possible specializations.


# Scope

The proposal [@P1636R2] has identified some formatters that are missing. This
proposal looks at more types that are streamable but not formattable. Also the
library has grown since then.


## Atomic values

These types are not streamable nor formattable. There is no proposal to add
these types. Users can already format the values by do this by using 

  `std::format("{}", atomic_value.load());`

This allows to specify the memory ordering of value. Adding a formatter for
this type would need to have a way to specify the memory order too. This seems
to needlessly add complexity to the Standard for little gain. The only benefit
from having it in the library would be that it's possible to format a
`vector<atomic<T>>` directly.

Indirectly this can be done by something along the lines of:

```cpp
int main() {
    std::array input{
        std::atomic<int>{1},
        std::atomic<int>{2},
        std::atomic<int>{3}
    };

  std::cout << std::format("{}", 
    input | std::views::transform([](auto& i) { return i.load(); }));
}
```



## Random engines and distributions

These types are streamable to store and load their internal state. This is a
set of decimal numbers, so it could be formatted as a range of integrals.
However the intention seems to be mainly be able to recreate the same random
engine or distribution and not to display the state. The author sees little
benefit from making these types formattable so the paper does not propose to
make these types formattable.


## Pointers and smart pointers

Currently only `void` pointers and `nullptr`s can be formatted. It might be
useful to format other pointers and smart pointers as well. [@P1636R2] proposed
this, but LEWG requested the smart pointers to be removed. Formatting pointers
sounds useful. However there are several design decision to be taken. The
author feels this would better be addressed in a separate paper.


## Utility types

There are several utility types: `optional`, `variant`, `any`, and `expected`
that would be nice to format. [@P2286R8] introduced formatting for `tuple` and
`pair` but didn't solve how to specify formatting of different underlying
types. These types would have the same issue. The author feels it would be
better to solve this issue before adding more formatters with the same issue.


## `filesystem::path`

This was proposed in [@P1636R2] and Victor Zverovich has shown interest to
write a paper for this type.


## `mdspan`

This type has no formatting support. It seems useful to be able to format this
type. However determining the best approach how to format this type has several
interesting non-trivial design choices. It seems better to do this in a
dedicated paper which takes `mdarray` ([@P1684R4]) also into account.


## `flat_map` and `flat_set`

There is no need to do anything for these container adaptors. These types are
handled by [@P2585R0] and are formatted the same way are their non-flat
equivalents.


## Diagnostics library

In the diagnostics library `error_code` is streamable but not formattable. The
similar type `error_condition` is neither streamable nor formattable. The
stream operator of `error_code` uses the value of the `error_category` which is
not streamable. [@P1636R2] proposes formatting of `error_code`.

It seems useful to make all these types formattable, especially the difference
between `error_code` and `error_condition` looks odd. The author has not been
able to find the historic reason for this discrepancy.

## Other types

There are some other types proposed in [@P1636R2] which have not been
incorporated in the Standard library:

  - `bitset`
  - `complex`
  - `sub_match`

LEWG was happy to add these types so this proposal adds these types.


## Byte

There are not proposals to add this type. Before [@P2286R8] a `std::byte`
formatter would only be easily able to format one element. After [@P2286R8] it
is possible to format ranges of elements. Since `std::byte` is intended to be
used to give a byte-oriented access to a memory range this seems very useful to
format. This makes it easy to print data received in buffers.


## Summary

There are several types that are interesting to be formattable, but that are
not in the current Standard. These can be divided in some groups:

  #. (smart) pointers
  #. utility types (`optional`, `variant`, `any`, and `expected`)
  #. filesystem
  #. `mdspan` (and `mdarray`)
  #. diagnostics
  #. `byte`
  #. the rest (`bitset`, `complex`, and `sub_match`)

This paper offers a solution for the last three items.


# Design decisions

The proposal [@P1636R2] is quite old, since that time the formatting library
has improved and other formatters have been added. For example the paper
[@P2286R8] solved some of the same problems that paper solves for `complex`. So
it seems better to follow that design instead of the original design.

From an implementers point of view some of the design choices are not optimal.
Forcing to inherit from `formatter<basic_string<charT>, charT>` is not optimal
in some cases. For example when a `sub_match` has a `contigious_iterator` there
is no reason to copy the matched result into a `basic_string`, using
`basic_string_view` would avoid the copy. The paper [@P2693R1] which proposed a
part of [@P1636R2] went in the same direction, only specifing what should
happen and no forced design choices for implementers.


## Drive by fix

Per [format.formatter.spec]{.sref}/2
:::bq
  Each header that declares the template formatter provides the following
  enabled specializations: 
:::

This requires every header that specializes a formatter to make the listed
specializations available. This seemed fine when format was used in a limited
number of places, however since its initial inception formatters have been
added to more places in the Standard library. This proposal adds more formatter
specializations, causing more headers to be affected.

The libc++ implementation uses granularized headers to reduce the size of the
translation units. This requirement requires libc++ to add extra granularized includes in
its implementation. Instead this paper proposes to only require these
specializations to be available when the header `format` is included. This
header defines the format functions that use these specializations.

Note when using modules the inclusion size is not relevant, but at the moment
of writing module support for the Standard library is not generally available.


## `Complex`

Both [@P1636R2] and [@P2197R0] have proposed this feature before. This
implementation ideas align with [@P2197R0].

The output format has two options:

  * A stream-like output that is similar to the output of ``operator<<``. This
    format still allows changing the output format of the floating-point values
    using the appropriate options of the _complex-format-spec_.
  * A range-like output that matches more with the format used in [@P2197R0].

The output is based on the range based formatters and uses the following ``format-spec``

> | _complex-format-spec_:
> |     _range-fill-and-align_~opt~ _width_~opt~ _n_~opt~ _complex-type_~opt~ _complex-underlying-type_~opt~
> | _complex-type_:
> |      `S`
> |      `r`
> | _complex-underlying-type_:
> |       : _format-spec_

The _format-spec_ of _complex-underlying-spec_ is applied to both the real and
the imaginary part of the complex number. This allows the user to have a
control on how these values are formatted. When the _complex-type_ is `r` there
are some special cases:

  * Since the sign is the separator between the real and imaginary part the
    imaginary part should always have a sign, else it will be hard to determine
	where the real part end. Therefore the sign option for the imaginary
	defaults to `+` and the option `-` is ignored. This still allows to use the
    `sign` option.

  * If the value is not infinity or NaN the value is suffixed with "i",
    otherwise the value is suffixed with " i". The differences is just for
	readability purposes. The suffix is part of the formatted value and counts
	to its width. Note the precision does not count the suffix as part of the
    precision.

The _complex-type_ behaves like:

  * `S` uses the output format similar to the `operator<<` output.
  * The _complex-type_ `r` uses the range based output format.

When no _complex-type_ the range based output format is used.

These letter are not used in the current _std-format-spec_ and alternative
would be to use `o` or `s` for the stream-like output. The option `S` will also
be used for the ``error_condition`` formatter where `o` and `s` have a
different meaning. For consistency the proposal uses `S` for all stream-like
output formats.

Some examples of the output for formatting `complex` values

| Value                | Format  | Output                       |
|----------------------|---------|------------------------------|
| complex{0, 0}        | {}      | (0+0i)                       |
| complex{3, 4}        | {}      | (3+4i)                       |
| complex{-3, 4}       | {}      | (-3+4i)                      |
| complex{3, -4}       | {}      | (3-4i)                       |
||||
| complex{nan, nan}    | {}      | (nan+nan i)                  |
| complex{-nan, -nan}  | {}      | (nan-nan i)                  |
| complex{inf, inf}    | {}      | (inf+inf i)                  |
| complex{-inf, -inf}  | {}      | (-inf-inf i)                 |
||||
|complex{0, 0}         | {:r}    | (0+0i)                       |
|complex{0, 0}         | {:nr}   | 0+0i                         |
|complex{0, 0}         | {:S}    | (0,0)                        |
|complex{0, 0}         | {:nS}   | 0,0                          |
||||
|complex{0, 0}         | {::#}   | (0.+0.i)                     |
|complex{1.345, 1.3}   | {:^^18} | ^^^(1.345+1.3i)^^^           |
|complex{1.345, 1.3}   | {::08}  | (0001.345+0001.3i)           |
|complex{1.345, 1.3}   | {::+08} | (+001.345+0001.3i)           |
|complex{1.345, 1.3}   | {::E}   | (1.345E+00+1.3E+00i)         |
|complex{1.345, 1.3}   | {::.6E} | (1.345000E+00+1.300000E+00i) |

Note to self, o only sets the separator, when the user changed the brackets that will be preserved. For example by using no as formatter.
This needs to be part of the wording


## `Bitset`

This type's formatting deviates from [@P1636R2], the original proposal's output
not bad, but very limited. Next to `to_string` the `bitset` the members
`to_ulong` and `to_ullong`, which allow an integral value. Another way to look
at a `bitset` is a range of bits. Formatting allows all these different views:

  * As a `string`. This uses the `bitset`'s `to_string` member function.
    The contents are a representatation of the value and not a
    specific string. This means the output can't be truncated with a precision
    option, nor does it have the debug option.
  * As an `integral`. Since the value is always unsigned and it is not a real
	artithmetic value the sign option is not allowed. Implemenenations can the
    member functions `to_ulong()` or `to_ullong()`. Implementations are not allowed
	to throw `overflow_error` when the value fits in an `unsigned long long`.
	The usage of `to_ulong()` is intended to be allowed as optimization when it
    is known the value will fit in an `unsigned long`, for example when the using a
    `bitset<8>`.
	When the value does not fit in an `unsigned long long` it is implementation
    defined whether an implementation throws `overflow_error` or outputs the
	correct value. Implementations are allowed to change this behaviour
	depending on the display type, for example throw for the decimal display
    type, but write values for the binary display type. The provided implementation
    has an example where a binary display type never throws.
  * As a range of `bool` values, where the underlying `bool` can be configured
    like the normal `bool` value.

The formatter will use the following `format-spec`.

> | _bitset-format-spec_:
> |     _range-fill-and-align_~opt~ _#_~opt~ _0_~opt~ _width_~opt~ _L_~opt~ _n_~opt~ _bitset-type_~opt~ _bitset-underlying-type_~opt~
> | _bitset-type_: one of
> |      `b` `B` `d` `o` `x` `X` `r` `s`
> | _bitset-underlying-type_:
> |       : _format-spec_

Most fields match the behaviour of the _std-format-spec_
([format.string.std]{.sref}) or the _range-format-spec_
([format.range.formatter]{.sref}).

The _n_ option is only valid when the output is range-based.

The `r` option of _bitset-type_ selects the range-based output. This implies
the underlying bits are outputted in the same way as the `bool` formatter.

The _bitset-underlying-type_ is only valid when the output is range-based.

The _format-spec_ of the _bitset-underlying-type_ matches the _format-spec_ of
a the `bool` type.

Some examples of the output for formatting `bitset` values

| Value                | Format  | Output                       |
|----------------------|---------|------------------------------|
| bitset<4>{0x5}       | {}      | 0101                         |
| bitset<4>{0x5}       | {:s}    | 0101                         |
| bitset<4>{0x5}       | {:b}    | 101                          |
| bitset<4>{0x5}       | {:#B}   | 0B101                        |
| bitset<4>{0x5}       | {:r}    | [false, true, false, true]   |
| bitset<4>{0x5}       | {:r:b}  | [0, 1, 0, 1]                 |
| bitset<4>{0x5}       | {:nr:b} | 0, 1, 0, 1                   |

XXX query for the typical sizes of N for a bitset in CODESEARCH https://codesearch.isocpp.org/


### `Bitset` reference

Like `vector<bool>` the returned type of the non-`const` member
`operator[](size_t)` of a `bitset` is a proxy. The formatter for this proxy is
modeled after the proxy of `vector<bool>`.

(Note that the provided libc++ implementation tests for a
`bitset<N>::const_reference`-like type too. This is due libc++ returning
a non-conforming proxy from the `const` member `operator[](size_t)` is some ABI
versions. These tests also work on confirming implementations returning a
`bool`.)

The _format-spec_ for this type is identical to the _std-format-spec_ of a boolean.


## `Sub_match`

This type's formatting matches [@P1636R2], but the wording takes a different
approach. It's likely `sub_match` uses a `contiguous_iterator`, forcing
the range to be copied to a `string` and then copied to the output adds
unneeded overhead. The wording gives implementations options to pick other
types. For example a `basic_string_view` for a `contiguous_iterator` and a
`basic_string` for a non-`contiguous_iterator`.

The _format-spec_ for this type is identical to the _std-format-spec_ of a
string type.


## Diagnostics

All these formatters may use ``error_category::name()``. This function returns
a `string` and has no option to return a `wstring`. The same holds true for the
`message` member function of `error_code` and `error_condition`. Therefore
these formatters are only specialized for `charT` is `char`. The same approach
is already used for the `stacktrace_entry` formatter.


### `Error_code`

This type's formatting deviates from [@P1636R2], the original proposal's output
feels limited. It is based on the output of `operator<<`.
Customizing the output of this operator for custom types is non-trivial, but
formatters don't have this limitation. Instead of limiting the output of the
formatter, let's embrace it. Some of the limitations are that it is not
possible to write the error's message which may contain useful information.

It could be argued that the decimal output may not be portable across
platforms. For example EOVERFLOW has the value `75` on Linux and `132` on
Windows. However this value is currently already used in `operator<<`, so
exposing the value in format seems natural.

https://learn.microsoft.com/en-us/cpp/c-runtime-library/errno-constants?view=msvc-170

The formatter will use the following `format-spec`.

> | _error-code-format-spec_:
> |     _fill-and-align_~opt~ _#_~opt~ _0_~opt~ _width_~opt~ _L_~opt~ _error-code-type_~opt~
> | _error-code-type_: one of
> |     _error-code-type-value_ _error-code-type-message_ _error-code-type-ostream_
> | _error-code-type-value_: one of
> |      `b` `B` `d` `o` `x` `X`
> | _error-code-type-message_:
> |      `s`
> | _error-code-type-ostream_:
> |      `S`       

Most fields match the behaviour of the _std-format-spec_
([format.string.std]{.sref}).

When _error-code-type_ is a _error-code-type-value_ the value is formatted as
an `int` obtained by calling the `value()` member function.

When _error-code-type_ is a _error-code-type-message_ the value is formatted as
a `string` obtained by calling the `message()` member function.

When _error-code-type_ is a _error-code-type-ostream_ the value is formatted
is the same way the output of `operator<<`. When this display type is used only
the _fill-and-align_ and _width_ option may be present.

When the _error-code-type_ is omitted it is formatted as-if the
_error-code-type-istream_ has been specified.

Note `ostream<<` has a charT as template argument. However the implementation
does not work when charT is not char. The formatter is only available for char
types.

XXX LWG issue
[syserr.errcode.nonmembers]/1
Constrains charT same_as char


Formatting the ``make_error_code(errc::value_too_large);`` may give the following results:

| Format  | Output                                |
|---------|---------------------------------------|
| {}      | Value too large for defined data type |
| {:s}    | Value too large for defined data type |
| {:d}    | 75                                    |
| {:S}    | generic:75                            |


### `Error_condition`

This type is similar to `error_code`, but it has no `operator<<`. It's unclear
to the author what the historic reason for the difference. This proposal
proposes to add an `error_condition` formatter. This formatter behaves the same
as the `error_code` formatter.


### `Error_category`

This formatter behaves the same as a formatter for a string type using taking
its value from the `name()` member function with the following exceptions.
Except the precision option is not available.

Formatting the `generic_category();`` gives the following results:

| Format  | Output                               |
|---------|--------------------------------------|
| {}      | generic                              |
| {:s}    | generic                              |
| {:.42}  | // ill-formed, precision not allowed |


## Byte

There are no previous proposals for this type. The type is intended to be used
as a memory buffer containing bytes. With the presence of range-based
formatting it seems useful to be able to format this memory buffer.

This type is defined in `cstddef`. It feels wrong to add a `formatter` to a c
header. Instead this formatter specialization will be available in the
`<format>` header.

Since the type is small it makes sense to directly store the byte in the
`basic_format_arg` exposition only value variant. However this change may be
problematic for implementers due to

[format.args]{.sref}/1
:::bq
  An instance of basic_format_args provides access to formatting arguments.
  Implementations should optimize the representation of basic_format_args for a
  small number of formatting arguments.
  [Note 1: For example, by storing indices of type alternatives separately from values and packing the former. — end note]
:::

Implementations have implemented this packing in different ways. Also implementations have their different extensions for the value variant:

  * libc++ 128 bit integral types
  * libstdc++ 128 bit integral types and extended floating-point types
  * MSVC STL has no extensions

Instead of requiring implementers to add it to the variant it is unspecified
whether the value is stored directly in the handle or in the variant.  This
difference is observable when users call `visit_format_arg`. Searching for this
string on GitHub only finds usage of this function in fmt, llvm, gcc, MSVC STL
and the LWG issue repositories of forks of them. So it's not really used by
users.

Usage we can either keep that unspecified too, alternatively it would be
possible to specify this type is not visitable. Requiring it to be always
visitibale would require a new entry in the type enum, which basically requires
storing in the enum

The formatter itself behaves like the formatter for int except that it does not
allow the char display type.  When formatting a byte as a char half of the
values can not be represented in a char if char is a signed. For wchar_t all
values can be represented.  When a value can't be represented as a char the
formatter throws and exception. 

# Open questions

## Drive-by

Should this be an LWG issue?

## Complex

more advanced like Victor's proposal?

# Questions

## To sign or not to sign

Two integer display types (`bitset` and `byte`) do not have the sign option in
their format-spec. Unsigned integrals do have this option. Do we want to keep
that or rather have the sign consistently?

## non-truncating string

There are several new non-truncating strings. There are two questions:

 - Do we want to avoid escaping them? Typically they will contain readable
   messages so escaping may do no more than adding quotes. But if they contain
   a newline it will be escaped... XXX maybe this makes sense a lot. TODO 

 - A non-truncating string seems useful in general, for example when users
   create a formatter for their `enum` classes. Does LEWG desire to expose this
   formatter so users can use this formatter as base for their own formatters?

   This formatter would have one parse function that only accepts a
   _fill-and-align_ and _width_ option. The format function would be overloaded
   for the string type specializations listed in [format.formatter.spec]{.sref}/2.2.


# Impact on the Standard

The proposal is a library only extension.

# Implementation experience

The proposal has been implemented in a branch of libc++. This branch is not shiped with libc++.


# Proposed wording

## Feature test macro

Update the macro ``__cpp_lib_formatters`` to the date of addoption and make it available in the following additional headers
`<bitset>`, `<complex>`, `<regex>`, `<system_error>`, `<format>`.


## Drive-by

[format.formatter.spec]{.sref}/2

:::bq
```diff
- Each header that declares the template formatter provides the following enabled specializations: 
+ This header provides the following enabled specializations:
```
:::


## Formatter `complex`

Add to [complex.syn]{.sref}

::: bq
```diff
   template<class T> complex<T> tan  (const complex<T>&);
   template<class T> complex<T> tanh (const complex<T>&);
 
+  // [complex.format], complex formatting
+  template<class T, class charT>
+  struct formatter<complex<T>, charT>;  
+
   // [complex.literals], complex literals
   inline namespace literals {
   inline namespace complex_literals {
```
:::

Add a new section 26.4.? Formatting [complex.format]:

::: bq
::: add
```
namespace std {
  template<class T, class charT>
  class formatter<complex<T>, charT {
    formatter<T, charT> underlying_;                                          // exposition only
    basic_string_view<charT> separator_ = STATICALLY-WIDEN<charT>("");        // exposition only
    basic_string_view<charT> opening-bracket_ = STATICALLY-WIDEN<charT>("("); // exposition only
    basic_string_view<charT> closing-bracket_ = STATICALLY-WIDEN<charT>(")"); // exposition only

  public:
    constexpr void set_separator(basic_string_view<charT> sep) noexcept;
    constexpr void set_brackets(basic_string_view<charT> opening,
                                basic_string_view<charT> closing) noexcept;

    template<class ParseContext>
      constexpr typename ParseContext::iterator
        parse(ParseContext& ctx);

    template<class FormatContext>
      typename FormatContext::iterator
        format(complex<T> value, FormatContext& ctx) const;
  };
}
```

[1]{.pnum} `template<class T, class charT> class formatter<complex<T>, charT>;`

`formatter<complex<T>, charT>` interprets _format-spec_ as a _complex-format-spec_. The
syntax of format specifications is as follows:

> | _complex-format-spec_:
> |     _range-fill-and-align_~opt~ _width_~opt~ _n_~opt~ _complex-type_~opt~ _complex-underlying-type_~opt~
> | _complex-type_:
> |      `S`
> |      `r`
> | _complex-underlying-type_:
> |       : _format-spec_


[2]{.pnum} _range-fill-and-align_ is interpreted the same way as a described in
[format.range.formatter]{.sref}.

[3]{.pnum} _width_ is interpreted the same way as a described in
[format.string]{.sref}.

[4]{.pnum} _n_ is interpreted the same way as a described in
[format.range.formatter]{.sref}.

[5]{.pnum} the _complex-type_ specifier changes the way a complex is formatted,
with certain options only valid with certain argument types. The meaning of
the various type options is as specified in Table xx.

Table xx: Meaning of complex-type options [tab:complex.format.type]

+--------+--------------------------------------------------------------------+
| Option | Meaning                                                            |
+========+====================================================================+
| `S`    | The output is compatible with the ostream output.                  |
|        | Indicates the separator should be STATICALLY-WIDEN(", "),          |
|        | and `markup-imaginary-part_` should be `false.                     |
|        |                                                                    |
|        |                                                                    |
+--------+--------------------------------------------------------------------+
| `r`    | The output is compatible with the format output.                   |
+--------+--------------------------------------------------------------------+
| none   | The same as `r`.                                                   |
+--------+--------------------------------------------------------------------+

[6]{.pnum} The _format-spec_ in a _complex-underlying-spec_, if any, is
interpreted as the _std-format-spec_ for a floating-point type as described in
[format.string]{.sref}.

`constexpr void set_separator(basic_string_view<charT> sep) noexcept;`

[7]{.pnum} _Effects_: Equivalent to: `separator_ = sep;`


```
constexpr void set_brackets(basic_string_view<charT> opening,
                            basic_string_view<charT> closing) noexcept;
```

[8]{.pnum} _Effects_: Equivalent to:
```
  opening-bracket_ = opening;
  closing-bracket_ = closing;

```

```
template<class ParseContext>
  constexpr typename ParseContext::iterator
    parse(ParseContext& ctx);
```

[9]{.pnum} _Effects_: Parses the format specifier as a _complex-format-spec_ and
stores the parsed specifiers in `*this`.  The values of `opening-bracket_`,
`closing-bracket_`, `separator_`, and `markup-imaginary-part_` are modified if
and only if required by the _range-type_ or the _n_ option, if present. The
function `underlying_.parse()` is called with the _format-spec_ of
_complex-underlying-spec_.


[10]{.pnum} _Returns_: An iterator past the end of the _complex-format-spec_.


```
template<class FormatContext>
  typename FormatContext::iterator
    format(complex<T> value, FormatContext& ctx) const;

```

[11]{.pnum} _Effects_: Writes the following into `ctx.out()`, adjusted according to the _complex-format-spec_:

[11.1]{.pnum} - `opening-bracket_`,

[11.2]{.pnum} - `value.real()`  via `underlying_`,

[11.3]{.pnum} - `separator_`,

[11.5]{.pnum} - `value.imag()`  via `underlying_`.
If _complex-type_ is not `S` `underlying_` and  `underlying_.parse()` was called without a _sign_ option or a _sign_ option `-`,
adjust the ouput as-if `underlying_.parse()` was called with _sign_ option `+`.

[11.5]{.pnum} - if _complex-type_ is not `S`,
if `value.imag()` is not infinity or NaN, write ``STATICALLY-WIDEN(" i")` else write `STATICALLY-WIDEN(" i")`, and

[11.6]{.pnum} - `closing-bracket_`.

[xx: ```
string s0 = format("{}", complex{0.0, 0.0});         // s0 has value: (0+0i)
string s1 = format("{::-}", complex{0.0, 0.0});      // s1 has value: (0+0i)
string s2 = format("{:: }", complex{0.0, 0.0});      // s2 has value: ( 0 0i)
string s3 = format("{::+}", complex{0.0, 0.0});      // s3 has value: (+0 0i)
string s4 = format("{:S:}", complex{0.0, 0.0});      // s4 has value: (0,0)

double inf = numeric_limits<double>::infinity();
double nan = numeric_limits<double>::quiet_NaN();
string s5 = format("{::}", complex{inf, nan});       // s5 has value: (inf+nan i)
string s6 = format("{:S:}", complex{inf, nan});      // s6 has value: (inf,nan)
```]{.example}

[12]{.pnum} _Returns_: An iterator past the end of the output range.

:::
:::


## Formatters `bitset` and `bitset::reference`

Add to [bitset.syn]{.sref}

::: bq
```diff
   template<class charT, class traits, size_t N>
     basic_ostream<charT, traits>&
       operator<<(basic_ostream<charT, traits>& os, const bitset<N>& x);

+  // [bitset.format], formatter specialization for bitset
+  template<size_t N, class charT> struct formatter<bitset<N>, charT>; 
+
+  template<class T>
+    constexpr bool is-bitset-reference = see below;          // exposition only
+
+  template<class T, class charT> requires is-bitset-reference<T>
+    struct formatter<T, charT>; 
+
 }
```
:::

::: bq
```diff
 [3]{.pnum} The functions described in [template.bitset]{.sref} can report three kinds of errors, each associated with a distinct exception:

 [3.1]{.pnum} an _invalid-argument_ error is associated with exceptions of type `invalid_argument` ([invalid.argument]{.sref});

 [3.2]{.pnum} an _out-of-range_ error is associated with exceptions of type out_of_range ([out.of.range]{.sref});

 [3.3]{.pnum} an _overflow_ error is associated with exceptions of type overflow_error ([overflow.error]{.sref}).

+template<class T>
+  constexpr bool is-bitset-reference = see below;
+ [4]{.pnum} The expression is-bitset-reference<T> is true if T denotes the type `template<size_t N> bitset<N>::reference`.

```
:::


Add a new section 22.9.? Formatting [bitset.format]:

::: bq
::: add
```
namespace std {
  template<size_t N, class charT = char>
  class formatter<bitset<N>, charT {
    basic_string_view<charT> separator_ = STATICALLY-WIDEN<charT>("");        // exposition only
    basic_string_view<charT> opening-bracket_ = STATICALLY-WIDEN<charT>("("); // exposition only
    basic_string_view<charT> closing-bracket_ = STATICALLY-WIDEN<charT>(")"); // exposition only
    charT zero_ = CharT('0');                                                 // exposition only
    charT one_ = CharT('1');                                                  // exposition only

  public:
    constexpr void set_separator(basic_string_view<charT> sep) noexcept;
    constexpr void set_brackets(basic_string_view<charT> opening,
                                basic_string_view<charT> closing) noexcept;
    constexpr void set_zero_one(charT zero, charT one) noexcept;

    template<class ParseContext>
      constexpr typename ParseContext::iterator
        parse(ParseContext& ctx);

    template<class FormatContext>
      typename FormatContext::iterator
        format(complex<T> value, FormatContext& ctx) const;
  };
}
```

[1]{.pnum} `template<size_t N, class charT> class formatter<bitset<N>, charT>;`

`formatter<bitset<N>, charT>` interprets _format-spec_ as a _bitset-format-spec_. The
syntax of format specifications is as follows:

> | _bitset-format-spec_:
> |     _range-fill-and-align_~opt~ _#_~opt~ _0_~opt~ _width_~opt~ _L_~opt~ _n_~opt~ _bitset-type_~opt~ _bitset-underlying-type_~opt~
> | _bitset-type_: one of
> |      `b` `B` `d` `o` `x` `X` `r` `s`
> | _bitset-underlying-type_:
> |       : _format-spec_

[2]{.pnum} _range-fill-and-align_, is interpreted the same way as a described in
[format.range.formatter]{.sref}.

[3]{.pnum} _#_, _0_, _width_, _L_ are interpreted the same way as a described in
[format.string]{.sref}.

[4]{.pnum} _n_ is interpreted the same way as a described in
[format.range.formatter]{.sref}.

[5]{.pnum} the _bitset-type_ specifier changes the way a bitset is formatted,
with certain options only valid with certain argument types. The meaning of
the various type options is as specified in Table xx.

Table xx: Meaning of complex-type options [tab:complex.format.type]

+----------+------------------------------------------------------------------+
| Option   | Meaning                                                          |
+==========+==================================================================+
| `b`, `B`,| Is formatted as if formatting the output of                      |
| `d, `o`, | `bitset<N>::to_ullong()`.                                        |
| `x`, `X` | If the value can not be represented in `unsigned long long`      |
|          | it is implementation defined whether the value is formatted      |
|          | as an integral or an `overflow_error` is thrown.                 |
|          |                                                                  |
|          | Implementations may use different behavior for the different     |
|          | options.                                                         |
|          |                                                                  |
|          | [This allows to generate output for the `b` option and throwing  |
|          | for the `d` option.[{.note}                                      |
+----------+------------------------------------------------------------------+
| `r`      | The output is formatted as a range of boolean values.            |
+----------+------------------------------------------------------------------+
| `s`      | Is formatted as if formatting the output of                      |
|          | `bitset<N>::to_string(zero_, one_)`.                             |
+----------+------------------------------------------------------------------+
| none     | The same  `s`.                                                   |
+----------+------------------------------------------------------------------+

[6]{.pnum} The _format-spec_ in a _bitset-underlying-spec_, if any, is
interpreted as the _std-format-spec_ for a `bool` type as described in
[format.string]{.sref}. The _bitset-underlying-spec_ is only valid when
the _type_ option is `r`.

```
template<class T>
  constexpr bool is-bitset-reference = see below;
```

[7]{.pnum} The variable template is-bitset-reference<T> is true if T denotes
the type `bitset<N>::reference` for some value of `N` and `bitset<N>` is not a
program-defined specialization.

```
template<class T, class charT> requires is-bitset-reference<T>
  struct formatter<T, charT> {
  private:
    formatter<bool, charT> underlying_;     // exposition only

  public:
    template <class ParseContext>
      constexpr typename ParseContext::iterator
        parse(ParseContext& ctx);

    template <class FormatContext>
      typename FormatContext::iterator
        format(const T& ref, FormatContext& ctx) const;
  };
```

```
template <class ParseContext>
  constexpr typename ParseContext::iterator
    parse(ParseContext& ctx);
```

[8]{.pnum} Effects: Equivalent to return underlying_.parse(ctx);

```
template <class FormatContext>
  typename FormatContext::iterator
    format(const T& ref, FormatContext& ctx) const;
```

[9]{.pnum} Effects: Equivalent to return underlying_.format(ref, ctx);

:::
:::

XXX examples


## Formatter `sub_match`

Add to [re.syn]{.sref}

::: bq
```diff
   template<class charT, class ST, class BiIter>
     basic_ostream<charT, ST>&
       operator<<(basic_ostream<charT, ST>& os, const sub_match<BiIter>& m);

+  // [re.submatch.format], complex formatting
+  template<class BiIter, class charT>
+  struct formatter<sub_match<BiIter>, charT>;  
+
   // [re.results], class template match_results
   template<class BidirectionalIterator,
            class Allocator = allocator<sub_match<BidirectionalIterator>>>
     class match_results;
```
:::

Add a new section 38.8.? Formatting [re.submatch.format]:

::: bq
::: add
[1]{.pnum} `formatter<sub_match<BiIter>, charT>` is a _debug-enabled_ string type specialization ([format.formatter.spec]{.sref}).

[2]{.pnum} The formatter outputs the result of the `sub_match`'s `str()`.

:::
:::

## Header `system_error`

Add to [system.error.syn]{.sref}

::: bq
```diff
   // [syserr.compare], comparison operator functions
   bool operator==(const error_code& lhs, const error_code& rhs) noexcept;
   bool operator==(const error_code& lhs, const error_condition& rhs) noexcept;
   bool operator==(const error_condition& lhs, const error_condition& rhs) noexcept;
   strong_ordering operator<=>(const error_code& lhs, const error_code& rhs) noexcept;
   strong_ordering operator<=>(const error_condition& lhs, const error_condition& rhs) noexcept;
+
+  // [syserr.format], formatter support
+  template<> struct formatter<error_category>;
+  template<> struct formatter<error_code>;
+  template<> struct formatter<error_condition>;
 
   // [syserr.hash], hash support
   template<class T> struct hash;
   template<> struct hash<error_code>;
   template<> struct hash<error_condition>;
```
:::


Add a new section 19.5.? Formatting [syserr.format]:

::: bq
::: add

[1]{.pnum} For each of `error_code` and `error_condition`, the library provides
the following formatter specialization where `error-code` is the name of the
template.

```
template<> struct formatter<error-code>;
```
[1]{.pnum} `formatter<error-code>` interprets _format-spec_ as a
_error-type-format-spec_.  The syntax of format specifications is as follows:

> | _error-code-format-spec_:
> |     _fill-and-align_~opt~ _#_~opt~ _0_~opt~ _width_~opt~ _L_~opt~ _error-code-type_~opt~
> | _error-code-type_: one of
> |     _error-code-type-value_ _error-code-type-message_ _error-code-type-ostream_
> | _error-code-type-value_: one of
> |      `b` `B` `d` `o` `x` `X`
> | _error-code-type-message_:
> |      `s`
> | _error-code-type-ostream_:
> |      `S`       

[3]{.pnum} _fill-and-align_, _#_, _0_, _width_, _L_ are interpreted the same
way as a described in [format.string]{.sref}.

[4]{.pnum} When _error-code-type_ is a _error-code-type-value_ the value is
formatted as an `int` obtained by calling the `value()` member function.

[5]{.pnum} When _error-code-type_ is a _error-code-type-message_ the value is
formatted as a `string` obtained by calling the `message()` member function.

[6]{.pnum} When _error-code-type_ is a _error-code-type-ostream_ the value is
formatted is the same way the output of `operator<<`. When this display type is
used only the _fill-and-align_ and _width_ option may be present.

[7]{.pnum} When the _error-code-type_ is omitted it is formatted as-if the
_error-code-type-ostream_ has been specified.

:::
:::


## Byte






https://github.com/cplusplus/papers/issues/425
