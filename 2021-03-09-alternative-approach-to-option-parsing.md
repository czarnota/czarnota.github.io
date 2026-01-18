---
layout: post
title:  "Alternative approach to option parsing"
date:   2021-03-09 11:28:00 +0100
author: P. Czarnota
---

Some time ago I posted about a declarative approach to the implementation of subcommand parsing in Bash scripts.
Turns out, that this approach can be extended to also support long (like `--long`) and short (like `-s`) option parsing.

## Main function and multiple entry points

In my [previous post](/2020/03/21/subcommands-in-bash-scripts.html) about parsing subcommands, the idea for declarative subcommands was this:

```bash
foo () {
    shift # get rid of "foo" from arguments
    code_here
}
bar () {
    shift # get rid of "bar" from arguments
    code_here
}
main () {
    # shift not needed because it is a main entry point
    code_here
}

declare -A COMMANDS=(
    [foo]=foo
    [bar]=bar
    [main]=main
)

# Try ${COMMANDS[$1]} first
# If $1 is not defined then try ${COMMANDS[main]}
# If $1 is defined, but ${COMMANDS[$1]} does not exist, then try ${COMMANDS[main]}
# Finally, pass all arguments to the selected entry point
"${COMMANDS["${1-main}"]:-${COMMANDS[main]}}" "$@"
```

This way, if we invoke `./script foo X Y Z`, it will invoke `foo()` function and the arguments are going to be `X Y Z` (the same goes for `bar` subcommand). If we invoke `./script X Y Z` it will invoke `main()` function (default entry point) and the arguments going to be `X Y Z`.
This approach to subcommand parsing can be also utilized for option parsing.

## Option parsing

We can implement option parsing by extending the approach to argument parsing in a few steps.

### Step one:
Wrap the argument parsing one-liner into a function (let's call it `argparse`)

```bash
argparse () {
    "${COMMANDS["${1-main}"]:-${COMMANDS[main]}}" "$@"
}

argparse "$@"
```

We are doing this, because we will be invoking the "argument parsing one-liner" multiple times, so that
we can parse multiple options.

### Step two

Add script options to `COMMANDS` associative array. 

As an example we will add two options:
- `--long ARG` - long option, which accepts a single mandatory argument 
- `-s ARG` - show option, which accepts a single mandatory argument

Here is the `COMMANDS` array after the changes:
```bash
declare -A COMMANDS=(
    [foo]=foo
    [bar]=bar
    [main]=main
    [--long]=set_value
    [-s]=set_value
)
```

So what is `set_value`? 
It is a name of the function, which does two things:

1. Parses an option
2. Runs `argparse` again

This function can be implemented like this:
```bash
set_value () {
     local OPT_{$1//-/}="$2" # Remove hyphens, as they are not valid variable names
     shift 2 || { echo "err: $1 requires an argument" 1>&2; return 1; }
     argparse "$@" # Run 'argparse()' for remaining arguments
}
```

Function `set_value()` will parse an option, and run `argparse()` again, which will parse next option or
call `${COMMANDS[main]}` if there are no more options to parse or if an option does not exist.

Then in the `main()` function (which is connected to "main" entry point) we can access script options using `$OPT_{option_name}` variables.

```bash
main () {
     echo $OPT_long
     echo $OPT_s
}
```

```console
$ ./script --long hello -s world
hello
world
```

# Support for "flag" options

Some options can act as simple on/off switches. We can implement those using `set_true` function, which
can be implemented as a simple wrapper for `set_value`.

```bash
set_true () {
    set_value "$1" true
}
```

```bash
declare -A COMMANDS=(
    [foo]=foo
    [bar]=bar
    [main]=main
    [--long]=set_value
    [-s]=set_value
    [--switch]=set_true
)
```

Then we can pass `--switch` option without arguments and it will be set to `true`
```bash
main () {
     echo $OPT_switch
}
```
```console
$ ./script --switch
true
```

All of this works great, but has one potential problem. Currently our option parsing works only for the "main entry point".
If we wanted to pass these options to specific subcommands it wouldn't work.

Here is an example that will not work:
```console
$ ./script foo --long hello
```
In the above example we will invoke `foo` entry point and stop argument parsing.
However if we specify `--long` option before the `foo`, then it will be parsed and the `foo()` function
will be executed with `$OPT_long` set to `hello`.
```
./script --long hello foo
```
But is this really a problem? I think this makes perfect sense. The `--long` option is a "top level" option for the script, and it affects the entire program.

But nevertheless, what if we wanted to implement option parsing for a specific subcommand? In other words, what if we wanted to make this work:
```console
$ ./script foo --long hello
```

Turns out, there is a way.

# Different set of options for subcommands

We will add option parsing to one of our entry points. Let's take `foo` entry point as an example.
The first thing we need to do is to wrap `foo()` in a function, which we will call `foo_parser()`

```bash
foo_parser () {
    foo "$@"
}
```

And instead of calling `foo()` when `foo` subcommand is selected we will call `foo_parser()`
```bash
declare -A COMMANDS=(
    [foo]=foo_parser # Just call foo_parser() instead of foo()
    [bar]=bar
    [main]=main
    [--long]=set_value
    [-s]=set_value
    [--switch]=set_true
)
```

Now in the `foo_parser()`, let's not call `foo()` directly. Instead overwrite `COMMANDS` array and call `foo()` through `argparse()`.
This allows us to handle options specific for `foo` entry point.
```bash
foo_parser () {
    shift
    declare -A COMMANDS=(
         [main]=foo
         [--long]=set_value
    )
    argparse "$@"
}
```

After the changes, this is supported:
```
$ ./script foo --long hello
```

Just one little detail - since `foo()` is called as a `main` entry point in `foo_parser()`, then we no longer need to `shift` its
name from the arguments.

So originally, the `foo` entry point used a `shift` to get rid of its name from arguments
```bash
foo () {
    shift # get rid of "foo" from arguments
    code_here
}
```

But now, it is not needed.
```bash
foo () {
     code_here
}
```

# Summary

Usually option and argument parsing is implemented using `while` loop combined with `case` statement.
Using an associative array and an "argument parsing one-liner", we can implement argument and option parsing in a declarative way.
