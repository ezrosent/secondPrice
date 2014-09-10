import std.random, std.container, std.conv, std.stdio, std.concurrency, core.thread,
       std.typetuple, std.array, std.traits;
import infrastructure;
import agents;

interface Auction(Ag) {
  public EndInformation run(Ag[] Agents/*, void delegate(Information) dumpIO*/);
}

template isAgent(T) {
  enum bool isAgent = is(T : Agent);
}

void agentSetup(/*Auct, */Agents...)(int numAuctions, int numRounds, int numAgents)
  if (allSatisfy!(isAgent,Agents)) in {
    assert((numAgents % Agents.length) == 0);
  } body {
  alias SecondPriceAuction!Agent Auct;

  static void loggerThread(int numAgents) {
    enum bufferSize = 4096;
    Information[bufferSize] buf;
    auto counter = 0;
    //print out agent manifest
    foreach(i; 0 .. numAgents) {
      receive((int i, string name) {writefln("%d -> %s", i, name); });
    }
    for (auto stopped = false; !stopped; ++counter){
      if (counter == bufferSize) {
        foreach (s; buf) writeln(s);
        counter = 0;
      }
      receive(
          (Information i) {buf[counter] = i;},
          (OwnerTerminated e) {stopped = true;}
      );
    }
  }

  auto loggerTid = spawn(&loggerThread, numAgents);
  immutable numPer = numAgents/Agents.length;
  auto  auction = new Auct(numRounds);

  Agent[] agents = uninitializedArray!(Agent[])(numAgents);
  { // add an equal number of agents of each type into the array
    // send them to logger thread to print the manifest
    auto counter = 0;
    foreach(T; Agents) {
      foreach(i;0 .. numPer){
        agents[counter] = new T(counter);
        loggerTid.send!(int,string)(counter, fullyQualifiedName!T);
        counter++;
      }
    }
  }

  foreach (auct; 0 .. numAuctions){
    //delegate causes assertion failure, aliasing thread-local storage
    auction.run(agents/*,(Information i) {loggerTid.send!Information(i);}*/);
  }
}

class SecondPriceAuction(Ag) : Auction!Ag {

  this(int nrounds) {
    _numRounds = nrounds;
  }

  public EndInformation run(Ag[] Agents/*, void delegate(Information) dumpIO*/) {
    alias writeln dumpIO; //hopefully I can make this work!
    double maxVal = -1,
           secondPrice = -1;
    Ag winningAgent = null;
    dumpIO(new StartInformation(_numRounds));
    foreach(round; 0 .. _numRounds) {
      Information inProgress() {
        return new ProgressInformation(_numRounds, new RealBid(secondPrice),
            round, winningAgent);
      }
      foreach(agent; Agents) {
        auto bid = agent.getInfo(info);
        auto val = bid.val;
        if (val > maxVal){
          secondPrice = maxVal;
          maxVal = val;
          winningAgent = agent;
        } else if (val > secondPrice) {
          secondPrice = val;
        }
      }
      dumpIO(inProgress());
    }

    assert(winningAgent !is null);
    _currentWinner = winningAgent;

    return new EndInformation(_numRounds, new RealBid(secondPrice),
        _numRounds-1, winningAgent);
  }

  private:
    Information info() { return new NullInformation(); }
    Ag _currentWinner;
    double _currentPayoff;
    double _reserve = 0.0;
    int _numRounds;
}

void main() {
  auto s = new SecondPriceAuction!Agent(1000);
  agentSetup!(/*SecondPriceAuction!Agent, */S1, S2, S3, S4, S5, S6)(10,100,600);
}
