---
title: "Chrono formatter issues"
document: XXXX
date: today
audience: LWG
author:
    - name: Mark de Wever
      email: <koraq@xs4all.nl>
toc: true
---

# Introduction


[@P1361R2] introduced formatting for `<chrono>`, [@P2372R3] improved the
handling of locales, and [@P1466R3] added several fixes. (There are more papers
than just this list.)

While implementing these papers in libc++ I noticed several small issues.
Instead of filing multiple LWG this paper lists and proposes resulutions these
issues. Since all issues could be filed as LWG issues I propose to
retro-actively apply these changes to C++20.

The `<chono>` implementation in libc++ is not complete at the time of writing;
several clocks are missing and all timezone parts are missing. Therefore there
has been no investigation whether these parts are implementable as is.

# Formatting `time_point`s and `duration`s with a floating-point representation type

## Formatting seconds

### Discussion

Several of the enabled formatter specializations listed in [time.syn]{.sref}
are or use a `duration`. When the representation is a floating-point type the
formatting of its fractional part is under specified.

[tab:time.format.spec]{.sref}
```
  %S … If the precision of the input cannot be exactly represented with
     seconds, then the format is a decimal floating-point number with a
     fixed format and a precision matching that of the precision of the
     input (or to a microseconds precision if the conversion to
     floating-point decimal seconds cannot be made within 18 fractional
     digits).
```

This wording is similar to [time.hms.members]{.sref}/1
```
  fractional_width is the number of fractional decimal digits represented by
  precision. fractional_width has the value of the smallest possible integer in
  the range [0, 18] such that precision will exactly represent all values of
  Duration. If no such value of fractional_width exists, then fractional_width
  is 6.
```

The latter makes it clear that floating-point values have 6 digits.

[@P2372R3] "§2 The solution" has a tony table of how formatting a seconds with
a `double` representation type


| Before 	                                | After                                     |
|-------------------------------------------|-------------------------------------------|
| auto s = std::format("{:%S}", sec(4.2));  | auto s = std::format("{:%S}", sec(4.2));  |
| // s == "04,200"                          | // s == "04.200"                          |
|-------------------------------------------|-------------------------------------------|
| auto s = std::format("{:L%S}", sec(4.2)); | auto s = std::format("{:L%S}", sec(4.2)); |
| // throws `format_error`                  | // s == "04,200"                          |
	
This indicates that floating-point value should have 3 digits.




	








# Duration

## Discussion



%q where units-suffix depends on the type Period​::​type as follows: not statically widen



%Q should this honour precision? Should this honour locale specific deciamal separator and grouping?

%S The duration can be stored as a floating-point value. It however is unclear how or when to output the decimals.

%S no grouping

%OS does this show decimals



# Outputting of invalid days

## Discussion

[time.cal.day.nonmembers]{.sref}/7
```cpp
template<class charT, class traits>
  basic_ostream<charT, traits>&
    operator<<(basic_ostream<charT, traits>& os, const day& d);
Effects: Equivalent to: return os << (d.ok() ?
  format(STATICALLY-WIDEN<charT>("{:%d}"), d) :
  format(STATICALLY-WIDEN<charT>("{:%d} is not a valid day"), d));

```

The output of the not valid days depends on the platform:

| Platform | Output 0d                | Output 255d              |
|----------|-------------------------:|-------------------------:|
| AIX      | "00 is not a valid day"  | "55 is not a valid day"  |
| Apple    | "00 is not a valid day"  | "255 is not a valid day" |
| Linux    | "00 is not a valid day"  | "255 is not a valid day" |
| MinGW    | " is not a valid day"    | " is not a valid day"    |

[comment]: # (TODO Add a proper reference to POSIX https://pubs.opengroup.org/onlinepubs/9699919799/functions/strftime.html)
[comment]: # (TODO List the implementation details for libc++, MSVC STL, fmt)

The issue stems from the library using `strftime` indirectly which is only
defined in the range [1 , 31]. Another thing to take into account is

[time.format]{.sref}/3
```
  If the formatted object does not contain the information the conversion
  specifier refers to, an exception of type format_error is thrown.
```

Does an object `d` of the type `chrono::day` contains the conversion in format
when `d.ok()` returns `false`. For some format specifiers this is explicitly
spelled out in [tab:time.format.spec]{.sref}, for example `%B` (full month
name) throws an exception when a `chrono::month` contains an invalid value, but
`%m` (month as decimal number) doesn't contain this wording.

A possible solution would be for implementation to implement the handling of
`%d` itself, this is quite easy; something along the line of
 `format(STATICALLY-WIDEN<charT>("{:02}"), static_cast<unsigned>(d)))`
would work.

Unfortunately that has another issue `%Od` needs to format the locale's
alternative representation. How this is done depends on the locale of the
system. Tests with the Japanese locale for libc++ shows only Linux uses an
alternative representation for the Japanese locale. (I mainly tested with
Japanese since that locale has both an alternative representation and an era
(for example `%EC`).

The locale information contains the first hundred numbers [0, 99] in the
locale's alternative representation. This gives the following results for
`format("{:%Od}", d);`


| d    | Output   |
|-----:|---------:|
| 0d   | "〇"     |
| 1d   | "一"     |
| 31d  | "三十一" |
| 255d | "255"    |




For other types like month the for invalid values doesn't rely on the chono
formatter to work correctly using invalid values. Therefore it seems better to
do this for all types.

- day
- year
- ymd


## Proposed resolution

::: bq
```diff
- format(STATICALLY-WIDEN<charT>("{:@[%d]{.diffdel}@} is not a valid day"), @[d]{.diffdel}@));
+ format(STATICALLY-WIDEN<charT>("{:@[02]{.diffins}@} is not a valid day"), @[static_cast\<unsigned\>(d)]{.diffins}@));
```
:::

Note to

[time.format]{.sref}/3

make things outside the valid range unspecified


# Formatting month

## Discussion

To output stream operator for an invalid month has an unused locale.


## Proposed resolution

::: bq
```diff
- format(os.getloc(), STATICALLY-WIDEN<charT>("{} is not a valid month"),
+ format(STATICALLY-WIDEN<charT>("{} is not a valid month"),
```
:::

# Formatting year

## Discussion

[tab:time.format.spec]{.sref}

`%C`
 * C++
	```
    The year divided by 100 using floored division. If the result is a single
    decimal digit, it is prefixed with 0.
    ```
 * C

   ```
   is replaced by the year divided by 100 and truncated to an integer, as a
   decimal number (00–99).
   ```

The interesting observation is C doesn't allow negative years to be a century.
This seems like an omission in the C Standard. For non-negative values there is
no difference between truncating and flooring.

For a negative number, due to the sign, the result is never a single digit. So
there is never padding. Changing this has an issue. [tab:time.parse.spec]
`%C`'s specification
```
The century as a decimal number. The modified command %NC specifies the maximum
number of characters to read. If N is not specified, the default is 2. Leading
zeroes are permitted but not required. The modified command %EC interprets the
locale's alternative representation of the century.
```
This by default accepts 2 characters, so `-09` would not be a valid century.
This may cause incompatibility between binaries when used by different compiler
versions. Since the benefit probably is small I propose no changes.
Alternatively the wording at both places could be modified.

| Year  | Century |
|------:|----------:|
| -801  | -9        |
| 999   | 09        |

`%Y`
```
The year as a decimal number. If the result is less than four digits it is
left-padded with 0 to four digits. The modified command %EY produces the
locale's alternative full year representation.
```

This wording doesn't work properly for negative years since the padding will be
in front of the sign.

This wording means `-1` would be padded to `000-1`. The proposal is to use zero padding.

| Year  | Before | After |
|------:|-------:|------:|
| -9999 | -9999  | -9999 |
| -999  | 0-999  | -0999 |
| 99    | 00-99  | -0099 |
| 9     | 000-9  | -0009 |
| 0     | 0000   | 0000  |
| 9     | 0009   | 0009  |
| 99    | 0099   | 0099  |
| 999   | 0999   | 0999  |
| 9999  | 9999   | 9999  |


## Proposed resolution

::: bq
```diff
- If the result is a single decimal digit, it is prefixed with 0.
+ If the result contains a single decimal digit, the digit is prefixed with a 0.
```
:::

# Streaming month day

## Discussion

[time.cal.md.nonmembers]{.sref}/7
```cpp
template<class charT, class traits>
  basic_ostream<charT, traits>&
    operator<<(basic_ostream<charT, traits>& os, const month_day& md);
Effects: Equivalent to:
    return os << format(os.getloc(), STATICALLY-WIDEN<charT>("{:L}/{}"),
                        md.month(), md.day());

```


If the month day is an invalid combination, like
February 30<sup>th</sup> the member function `ok()` returns `false`. However
the output of this function gives no indication of an error. This is
inconsistent with the other stream operators.

## Proposed resolution

::: bq
```diff
- return os << format(os.getloc(), STATICALLY-WIDEN<charT>("{:L}/{}"),
-                     md.month(), md.day());
+ return os << (!md.ok() && md.month().ok() && md.day().ok() ?
+   format(os.getloc(), STATICALLY-WIDEN<charT>("{:L}/{} is not a valid month day"),
+          md.month(), md.day()):
+   format(os.getloc(), STATICALLY-WIDEN<charT>("{:L}/{}"),
+          md.month(), md.day()));
```
:::

# Streaming year month weekday

## Discussion

[@LWG3273] extended the valid input range for `chrono::weekday_indexed` however
it didn't update the `ok` member function nor the `operator<<` non-member function.
This seems odd, when testing wheter a weekday is valid properly specified
values are rejected.

[time.cal.ymwd.members]{.sref}/10

::: bq
```diff
- Returns: If any of y_.ok(), m_.ok(), or wdi_.ok() is false, returns false.
+ Returns: If any of  y_.ok(), m_.ok(), or wdi_.weekday().ok(), or
+ wdi_.weekday().index <= 5 is false, returns false.
  Otherwise, if *this represents a valid date, returns true.
  Otherwise, returns false.
```
:::


[time.cal.ymwd.nonmembers]/11

::: bw
```diff
  Effects: Equivalent to:
- return os << format(os.getloc(), STATICALLY-WIDEN<charT>("{}/{:L}/{:L}"),
-                     ymwd.year(), ymwd.month(), ymwd.weekday_indexed());
+ return os << (ymwd.weekday_indexed().index() == 0) ?
+   format(os.getloc(), STATICALLY-WIDEN<charT>("{}/{:L}/{:L}[0]"),
+          ymwd.year(), ymwd.month(), ymwd.weekday_indexed().weekday()):
+   format(os.getloc(), STATICALLY-WIDEN<charT>("{}/{:L}/{:L}"),
+                     ymwd.year(), ymwd.month(), ymwd.weekday_indexed()));
```
:::





