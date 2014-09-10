/**
 * This is an implementation of the Iterated prisoner's dilema
 * evolutionary Agent-Based Model in Chapter 4 of Game Theory Evolving
 * by Herbert Gintis
 */
import std.stdio, std.random, std.algorithm,
       std.conv, std.parallelism, std.string, std.range;
static if (iothread){ import std.concurrency; }

template isNumeric(T) {
  enum bool isNumeric = is(T : long) || is(T : real);
}

//NVI for running a simple evolutionary simulation like this.
interface BasicReproductionSimulation(bool threaded) {
  public final void run(long nGen, long roundsPerCycle) {
    static if (threaded){
      debug writeln("Running with IO Thread");
      auto tid = spawn(&ioThread);
    }
    debug writeln ("starting run");
    foreach (i; 0 .. nGen) {
      foreach (j; 0 .. roundsPerCycle){
        debug writeln("round: ",j);
        play();
      }
      reproduce();
      static if (iothread){
        send(tid, dumpData());
      } else {
        writeln(dumpData());
      }
    }
  }
  static if (threaded) {
    // extra thread for buffered IO, reduces time spent on
    // IO, quite significantly for serial execution
    static private final void ioThread() {
      enum bufferSize = 6000;
      string[bufferSize] buf;
      auto i =0;
      for (bool stopped = false; !stopped; ++i){
        if (i == bufferSize){
          foreach (s; buf)
            writeln(s);
          i = 0;
        }
        receive(
            (string s) { buf[i] = s;},
            (OwnerTerminated e) { stopped = true; }
         );
      }
      debug writeln("IO thread exiting");
    }
  }
  protected:
    void play();
    void reproduce();
    string dumpData();
}

/**
 * This is the Game class which configures and manages the actual simulation
 * The payoff matrix is as follows for strategies Confess (C) and Defect (D)
 * (with reference to the class template parameters)
 *
 *                              C         D
 *                          ___________________
 *                         |         |         |
 *                      C  |  (r,r)  |  (s,t)  |
 *                         |_________|_________|
 *                         |         |         |
 *                      D  |  (t,s)  |  (p,p)  |
 *                         |_________|_________|
 */
class IteratedPrisoner(Agent, bool threaded, bool parallelize,
    NumT, NumT r, NumT t, NumT p, NumT s)
   : BasicReproductionSimulation!threaded if (isNumeric!NumT) {

  // if this isn't the case, it isn't a prisoner's dilema
  static assert( t > r && r > p && p > s);

  this(NumT nAgents = 200, NumT roundsPer = 100, double mutateRate = 0.05, 
      double deathRate = 0.05) {
      assert(nAgents > 0 && !(nAgents % 2) && roundsPer > 0);

      _numAgents = nAgents;
      _mutationRate = mutateRate;
      _deathRate = deathRate;
      _roundsPerGeneration = roundsPer;
      _agents = new Agent[nAgents];
      assignAgents(_agents);

  }

  invariant() { assert(_agents.length == _numAgents); }

  protected:
    // Random pairings of agents play iterated prisoners
    // dilemas per their strategies
    override void play() {
      randomShuffle(_agents);

      //cheaply group Agents by 2 to be passed to play(...)
      struct aPair {Agent a1; Agent a2;}
      static assert (aPair.init.sizeof == (2 * Agent.init.sizeof));

      static void play(Agent a1, Agent a2, int roundsPer) {
        a1.reset(); a2.reset();

        foreach (i; 1 .. (roundsPer + 1)){
          if (a1.defected || a2.defected) {
            a1.bumpResult(_punishment);
            a2.bumpResult(_punishment);
            continue;
          }
          bool defect1 = a1.decision(i),
               defect2 = a2.decision(i);

          switch (defect1 + defect2) {
            case 2:
              debug writefln("Round %d: %s, %s",i,a1,a2);
              a1.bumpResult(_punishment);
              a2.bumpResult(_punishment);
              break;
            case 1:
              a1.bumpResult(defect1 ? _temptation : _sucker);
              a2.bumpResult(defect2 ? _temptation : _sucker);
              break;
            case 0:
              a1.bumpResult(_reward);
              a2.bumpResult(_reward);
              break;
            default:
              assert(false);
          }
        }
      }
      aPair[] unsafeArray = cast(aPair[]) _agents;

      static if (parallelize) {
        void parallelPlay(int chunkSize) in {
          assert(( _agents.length % (chunkSize*2) ) == 0,
              format("chunksize*2=%d, length=%d", chunkSize * 2, _agents.length));
        } body {
          foreach(ref pair; parallel(unsafeArray,chunkSize)){
            play(pair.a1,pair.a2, _roundsPerGeneration);
          }
        }
        parallelPlay(15);
      } else {
        foreach (ref pair; unsafeArray) {
          play(pair.a1,pair.a2, _roundsPerGeneration);
        }
      }
    }

    override void reproduce() {
      // sort agents by fitness
      sort!((a,b) => a.result < b.result)(_agents);
      long toKill = cast(long) (_agents.length * _deathRate);

      //starting from the least fit, we kill with 95% chance
      //until there are toKill gone, we do this by replacing it with
      //a copy of a well performing agent (who mutates with probability _mutationRate)
      long killed = 0;
      long i=0;
      foreach_reverse (toReproduce; _agents){
        if (killed >= toKill) break;
        if (uniform(0.0,1.0) <= 0.95) {
          if (uniform(0.0,1.0) <= _mutationRate)
            _agents[i++] = new Agent(toReproduce.mutate(_roundsPerGeneration));
          else
            _agents[i++] = new Agent(toReproduce);
          ++killed;
        }
      }
      foreach (agent; _agents) {
        agent.resetResult();
      }
    }

    override string dumpData() {
      auto accum = 0.0;
      static run = 0;
      foreach (agent; _agents){
        accum += agent.defectAt;
      }
      accum /= _agents.length;
      return format("current run: %d average:%f", run++, accum);
    }

  private:
    // payoffs
    static immutable NumT _reward = r;
    static immutable NumT _temptation = t;
    static immutable NumT _punishment = p;
    static immutable NumT _sucker = s;

    // game parameters (which don't change)
    //    original number of agents, theoretically the size of _agents[] could vary
    immutable NumT    _numAgents;
    immutable NumT    _roundsPerGeneration;
    immutable double  _mutationRate;
    immutable double  _deathRate;

    Agent _agents[];

    void assignAgents(Agent[] agents) {
      foreach (ref agent; agents) {
        agent = new Agent(uniform(1, _roundsPerGeneration + 2));
      }
      debug writeln("Agents Assigned");
    }
}

//incremental mutation function
int incMutate(int defectAt, int maxVal)
  out (result) {
    auto diff = defectAt - result;
    if (diff < 0) diff = -diff;
    assert(result <= maxVal && result >= 0 && diff == 1,
        "diff=" ~ to!string(diff));
  } body {
    //coinflip, increase by one decrease by one
    auto retval = defectAt + (uniform(0.0,1.0) >= 0.5 ? 1 : -1);
    if (retval > maxVal)
      retval = maxVal;
    if (retval < 0)
      retval = 0;
    return retval;
}

//random mutation function
int randMutate(int defectAt, int maxVal) {
  return uniform(1,maxVal+2);
}

//takes parameter of mutation function
class PDAgent(alias func) {
  public:
    this(int defect){ defectAt = defect; }

    this(PDAgent agent) {
      this(agent.defectAt);
    }
    // True -> defect, False -> confess
    bool decision(long turn) {
      return (_defected = (defectAt == turn));
    }
    int mutate(int maxval){
      //auto retval = func(defectAt,maxval);
      return func(defectAt,maxval);
    }
    void bumpResult(long payoff) { _result += payoff;}
    void reset() {_defected = false;}
    void resetResult() {_result = 0;}
    @property int result() { return _result;}
    @property bool defected() { return _defected;}
    immutable int defectAt;
    override string toString() {
      return format("PDAgent(%d, %d)", defectAt, result);
    }
  private int _result = 0;
  private bool _defected = false;
}
//flags for different features
enum bool iothread = true;
enum bool parallelExecute = true;

void main(){
  auto myGame = new IteratedPrisoner!(PDAgent!incMutate,iothread,
      parallelExecute,int,2,5,1,-2)();
  myGame.run(100_000,10);
}
