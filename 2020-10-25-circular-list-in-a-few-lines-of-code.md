---
layout: post
title:  "Circular doubly linked list in just a few lines of code"
date:   2020-10-25 11:26:00 +0100
comments: true
tags:
  - c
---

Single linked lists are simple, doubly linked lists are harder,
but circular linked lists are definitely the most elegant types of lists and
it turns out that they are not actually that hard to implement.

What is the difference between a circular linked list and doubly linked list?
Well, in the circular list there are no `NULL` pointers indicating
the beginning or the end of the list. Instead, we indicate the start and the end a
of the list using the guard element (`G`).

![](/assets/circular-list-in-a-few-lines-of-code/0.svg)

This element usually has no payload associated with
it and acts only as a indicator for the beginning and the end of the list.
If a list has only one element then that element points to itself.

![](/assets/circular-list-in-a-few-lines-of-code/1.svg)

If such element has no payload, then it is a guard element and
represents an empty list. If the element has some payload associated with
it, then it is a free node that yet has not been connected to the list.
Everything forms a closed loop.

The structure for the circular linked list is really simple. It only requires
two pointers. One pointing to the next element (`next`) and another pointing the
previous element (`prev`).
```c
struct item {
    struct item *prev, *next;
};
```

## Storing payload
How do you store payload with such list? Well you can directly embed it
in the `struct item` like this:
```c
struct a {
    int a, b, c;
};

struct item {
    struct item *prev, *next;
    struct a payload;
};
```

Unfortunately, this way your list can only hold one type of payload (in this case `struct a`).
You can make it more generic by using a macro and define many types of lists
for different types of payload.

```c
#define LIST_ITEM_FOR(a) \
    struct item_##a { \
        struct item_##a *prev, *next; \
        a payload; \
    }

LIST_ITEM_FOR(int);
LIST_ITEM_FOR(struct a);
LIST_ITEM_FOR(struct b);
```
But then every type of such list will need a separate set of functions dedicated for
this specific type, which you will also need to define through a macro. And usually more
macros equal more trouble.

We can do this the other way around.
We can embed a `struct item` **into the payload structure**. Yes.
This way we can implement all list operations for a single `struct item` type.
If we want to access the payload, we can do so with the help of a very cool `container_of()` macro,
invented a long time ago by Linux kernel developers.

```c
#define container_of(ptr, type, member) \
	((type *)((char *)(ptr) - offsetof(type, member)))

// Or a more type safe version, which will not compile if "member" is
// of a different type than "ptr"
#define container_of(ptr, type, member) \
	((type *)((char *)(1 ? (ptr) : &((type *)0)->member) - offsetof(type, member)))
```

It allows you to get a pointer to the structure that `struct item` is embedded into, by using
a pointer to `struct item`.

```c
struct item {
    struct item *prev, *next;
};

struct a {
    struct item node;
    int a, b, c;
};
```

```c
struct a a;
struct item *p = &a.node;

// If you have a pointer to 'struct item', you can get 'struct a', in which
// it is embedded
struct a *pa = container_of(&p, struct a, node);
```

Ok. Let's implement the basic operations for this list.

## Linking two elements together

Let's say we have a bunch of list nodes.
To make a list we need to be able to link them together.
We need a function that will do this.
We will call it `list_link()`, because its purpose is to link two nodes together.

So given any two nodes, we want to link them so that one is placed before another.

![](/assets/circular-list-in-a-few-lines-of-code/3.svg)

Here is the code for such function. Its just two lines.
```c
void list_link(struct item *prev, struct item *next)
{
    prev->next = next;
    next->prev = prev;
}
```

That was easy and we've just got an element initializer for our list nodes for free.
To initalize a node we can link it with itself.

```c
struct item a;

list_link(&a, &a); // Link an item with itself to initalize it
```

This is how the node `a` looks like before and after it is initalized.

![](/assets/circular-list-in-a-few-lines-of-code/6.svg)

Ready for the next operation? It is even cooler.

## Splitting the list into two lists

Now let's write the second operation, whose purpose will bo to
split any circular list into two circular sublists by connecting two nodes.
Let's call this operation `list_split()`

So for any given list:

![](/assets/circular-list-in-a-few-lines-of-code/4.svg)

If we do `list_split()` at node `a` and `b` we get this.

![](/assets/circular-list-in-a-few-lines-of-code/5.svg)

The code for `list_split()` looks like that:

```c
void list_split(struct item *a, struct item *b)
{
    list_link(b->prev, a->next);
    list_link(a, b);
}
```

What is so cool about it? These are all operations you will mostly need.
The rest are just wrappers.

## Joining two lists together

Here we have a kind of a reverse situation

![](/assets/circular-list-in-a-few-lines-of-code/5.svg)

What is so cool about the `list_split()` is that if we call it
on `a` and `c`, we will join the two list back together! Yes!

![](/assets/circular-list-in-a-few-lines-of-code/4.svg)

So we can create a wrapper for this:
```c
void list_join(struct item *a, struct item *b)
{
    list_split(a, b);
}
```

## Adding an element to the list

Adding an element to the list is also easy. A single initialized element of the
list is also a circular linked list. So the operation is exactly the same as
`list_join()`

```c
void list_add(struct item *list, struct item *element)
{
    list_split(list, element);
}
```

If we want to add an element before (at the end), we can just reverse the
arguments.

```c
void list_add_before(struct item *list, struct item *element)
{
    list_split(element, list);
}
```

## Removing an element from the list

This is also cool.

```c
void list_remove(struct item *item)
{
    list_split(item, item);
}
```

Calling `list_remove(&a)` on the following list:

![](/assets/circular-list-in-a-few-lines-of-code/4.svg)

Will remove element `a` from the list.

![](/assets/circular-list-in-a-few-lines-of-code/7.svg)

## Summary

With just two operations `list_link()` and `list_split()`, you can
quickly implement a circular double linked list with basic functionality.

This is a pretty basic implementation, but for many cases it can be enough.
For more robust and field proven examples of circular linked lists take
a look at
[linux/list.h](https://github.com/torvalds/linux/blob/master/include/linux/list.h)
or [git/list.h](https://github.com/git/git/blob/master/list.h).
