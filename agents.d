import std.conv, std.random;
import infrastructure;


class S6 : Agent {
  this (int id) { super (id); }
  override protected double nextBid(Information info) {
    return (info.winningBid.val +
        (to!double(_value) / to!double(info.totalRounds)));
  }
}

//weighted moving average strategy
class S5: Agent {
  this (int id) {
    _prevBids = [0.0,0.0,0.0,0.0,0.0];
    super(id);
  }

  // coefficients for the weighted moving average
  enum x = 0.7, y = 0.2, z = 0.1;

  invariant() { assert(_prevBids.length == 5); }

  override protected double nextBid(Information info) {
    auto diff = (int a, int b) {return _prevBids[a] - _prevBids[b];};
/*    double diff(int a, int b) {*/
      //return _prevBids[a] - _prevBids[b];
    //}

    auto retval = x * diff(0,1) + y * diff(1,2) + z * diff(2,3);

    //shift all values to the right (representing a timestep)
    foreach_reverse(i, double j; _prevBids[0..$-1]) {
      _prevBids[i+1] = j;
    }
    _prevBids[0] = retval;

    return retval;
  }

  private double[] _prevBids;
}

class S4 : Agent {
  this (int id) { super(id);}
  override public double nextBid(Information info) {
    return (to!double(_value - info.winningBid.val) /
        to!double(info.totalRounds - info.currentRound));
  }
}


//Rate based increment 
class S3 : Agent {
  enum k = 0.1; // proportionality constant
  this (int id) { super(id);}

  override protected double nextBid(Information info) {
    return (_value - info.winningBid.val) * k;
  }
}



//Variable random increment
class S2 : Agent {
  enum range = 100.0;

  this (int id) { super(id);}

  override protected double nextBid(Information info) {
    return (info.winningBid.val + uniform(0.0,range));
  }
}

//constant minimal increment
class S1 : Agent {
  this(int id) {
    // randomly initialize increment
    _bidIncrement = uniform(0.0,1000.0);
    super(id);
  }
  override protected double nextBid(Information info) {
    return (info.winningBid.val + _bidIncrement);
  }
  private immutable double _bidIncrement;
}

//TODO: come up with way to do set value
class Agent  {

  this(int id) {
    ID = id;
    reset();
  }

  private void reset() {
    _prevBid = new NullBid;
  }

  public Bid getInfo(Information info) {
    if (info.infoT == InfoType.start) {
      reset();
    }
    return ReturnBid(nextBid(info));
  }

  private Bid ReturnBid(double newVal) {
    if (utility(newVal) < 0) {
      _prevBid = new NullBid();
    } else {
      _prevBid = new RealBid(newVal);
    }
    return _prevBid;
  }

  protected abstract double nextBid(Information info);

  protected double utility(double bid) const {
    return bid - _value;
  }
  public immutable int ID;
  private double _value;
  private Bid _prevBid;
}

