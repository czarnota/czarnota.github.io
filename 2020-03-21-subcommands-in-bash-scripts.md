---
layout: post
title:  "Subcommands in Bash scripts"
date:   2020-03-26 11:26:00 +0100
author: P. Czarnota
---

When your bash scripts start doing many things, then it may be a good idea to
split them. Alternatively, you can implement subcommands to have multiple entry points
into the script.

Usually this can be done very easily by few `if`s. Take a look at this example:

```bash
subcommand="$1";

shift;

if [[ $subcommand == foo ]]; then
    echo subcommand foo "$@"
elif [[ $subcommand == bar ]]; then
    echo subcommand bar "$@"
elif [[ $subcommand == baz ]]; then
    echo subcommand baz "$@"
fi
```

This is very straightforward and is working pretty good:

```console
$ ./script foo 1 2 3
subcommand foo 1 2 3
$ ./script bar 1 2 3
subcommand bar 1 2 3
$ ./script baz 1 2 3
subcommand baz 1 2 3
```

But it has one problem. This implementation of subcommands is basically a procedural
logic.
Even the simpliest kind of procedural logic can be often harder to understand
than a fairly complex data structure. There is even a popular quote by Fred Brooks

> Show me your code and conceal your data structures, and I shall continue to be mystified.
> Show me your data structures, and I won't usually need your code; it'll be obvious.
> -- <cite>Fred Brooks</cite>

And there is also the Rule of Representation, one of the rules of the Unix Philosophy

> Rule of Representation: Fold knowledge into data so program logic can be stupid and robust.

So how do we implement subcommands in a declarative way?

Declarative subcommands
-----------------------

Let's jump straight into the working example.

```bash
#!/usr/bin/env bash

usage () {
    echo unknown command: "$@"
    echo Usage: script foo|bar|baz ARGUMENTS
}

foo () {
    shift
    echo subcommand foo "$@"
}

bar () {
    shift
    echo subcommand bar "$@"
}

baz () {
    shift
    echo subcommand baz "$@"
}

# Associative array where we specify available entry points
declare -A COMMANDS=(
    [main]=usage
    [foo]=foo
    [bar]=bar
    [baz]=baz
)

# Magic line that makes it all working
"${COMMANDS[${1:-main}]:-${COMMANDS[main]}}" "$@"
```

Let us decode the magic line

```bash
"${COMMANDS[${1:-main}]:-${COMMANDS[main]}}" "$@"
```

Let's start with `${1:-main}`. This will return first argument passed to a script
and if there is no argument it will return `main`. So if the script is invoked
like this:

```console
$ ./scripts foo
```

We get:

```bash
"${COMMANDS[foo]:-${COMMANDS[main]}}" foo
#           ^^^--------- $1 here      ^^^----- expanded "$@"
```

And if no argument is provided

```console
$ ./scripts
```

It will become

```bash
"${COMMANDS[main]:-${COMMANDS[main]}}" 
#           ^^^^--------- $1 here      ^--- expanded "$@"
```

Let's go further. What if someone invokes the script with a subcommand that
does not exist? 

```console
$ ./scripts one two three
```

Then we will get

```bash
"${COMMANDS[one]:-${COMMANDS[main]}}" one two three
#           ^^^--------- $1 here      ^^^^^^^^^^^^^---- expanded "$@"
#  ^^^^^^^^^^^^^-------- this does not exist
```

The `"${COMMANDS[one]}` does not exist, so we will fall back
to `:-${COMMANDS[main]}`, and we will finally get this:

```bash
usage one two three
```

So if someone calls the script with the wrong command, it means that he is
really calling the `main` entry point. In our above case the `main` entry
point is set to a function called `usage()` so in this case we are going
to simply see the help message.

Arguments
---------

The last nuance is handling the actual arguments passed to subcommands.

Let's start with the `main` entry point. This is straightforward. The `main`
entry point is called either with no arguments or all arguments passed to the
script

```bash
usage () {
    echo unknown command: "$@"
    echo Usage: script foo|bar|baz ARGUMENTS
}
```

```console
$ ./script one two three
unknown command: one two three
echo Usage: script foo|bar|baz ARGUMENTS
```

But in the case of actual subcommands, they will also get all arguments, because
if we are calling a script with subcommand like this:

```console
$ ./script foo bar
```

We actually do this:

```bash
"${COMMANDS[${1:-main}]:-${COMMANDS[main]}}" "$@"
# and it will expand to
foo foo bar
```

So our subcommand receives 2 arguments: `foo` and `bar`, but it should receive
only `bar`. This is why we use the `shift` at the beginning of every subcommand

```bash
foo () {
    shift
    echo subcommand foo "$@"
}
```

I hope it was not too scary.
