#!/usr/bin/env python
"""
generates a basic graph of the output of Iterated Prisoners Dilema Simulation
"""
import pylab as plt
import re, sys, os

def parse_out(inf):
    """ process raw output"""
    line_pat = re.compile(r'current run: (\d+) average:(\d+\.\d+)')
    xdata = []
    ydata = []
    with open(inf) as in_file:
        for line in in_file:
            lmatch = line_pat.match(line)
            if lmatch is not None:
                xdata.append(int(lmatch.group(1)))
                ydata.append(float(lmatch.group(2)))
    return inf, xdata, ydata

def plot_run(name, xdata, ydata):
    """ plot output """
    plt.title('Evolution of Strategies Over Time')
    plt.ylabel('Average Defection Rate')
    plt.xlabel('Generation Number')

    plt.plot(xdata, ydata, color='r', linestyle='--')
    plt.savefig('%s.pdf' % name)
    plt.savefig('%s.png' % name)

if __name__ == '__main__':
    plot_run(*parse_out(sys.argv[1]))
