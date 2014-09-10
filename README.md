secondPrice
===========

Basic experiments with agent-based simulation of second-price auctions in D.

Most of this is intended as an exercise in my learning specific features
in the D programming language, but I would like to verify that these
results match the paper where this is from:``A Study on Internet Auctions Using
Agent Based Modeling Approach'' by Akkaya et. al.

This is far from completion, and is certainly at the pre-alpha stage.
Ideally it will later be extended to use more of D's threading features
and support for EDSLs as well.

The "iteratedPrison" directory is a more complete version of a simple
iterated prisoners dilema evolutionary agent-based model (complete with
a python script for graphing output). It demonstrates the general
interface I would like to have from this project, also the IO threading
is fully functional as no delegates have to be passed in that
implementation.
