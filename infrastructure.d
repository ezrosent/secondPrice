import std.string, std.conv;
import agents;
/**
	This module includes basic glue classes for the Auction
	participants to communicate with the game.
	*/
abstract class Bid {
  @property public double val() const;
	override public string toString() { return to!string(val()); }
}

final class NullBid : Bid {
  @property public override double val() const { return 0.0; }
}

final class RealBid : Bid {
  public:
    this (double bid) {
      _val = bid;
    }
    @property override double val() const { return _val; }
  private double _val;
}

enum InfoType { start, inProgress, end }

interface Information {
  @property public Bid winningBid();
  @property public int totalRounds();
	@property public int currentRound();
  @property public InfoType infoT();
}
//visitor?
class NullInformation : Information {
  public:
    @property override int totalRounds() { return 0;}
    @property override Bid winningBid() { return new NullBid(); }
    @property override InfoType infoT() const { return InfoType.inProgress; }
		@property override int currentRound() { return 0; }
}

class ProgressInformation : Information {
	public:
		this(int numRounds, Bid winningBid, int currentRound, 
				Agent winningAgent = new S1(-1)) {
			_numRounds = numRounds;
			_currentRound = currentRound;
			_winningBid = winningBid;
			_winningAgent = winningAgent;
		}
    @property override int totalRounds() { return _numRounds;}
    @property override Bid winningBid() { return _winningBid; }
    @property override InfoType infoT() const { return InfoType.inProgress; }
		@property override int currentRound() { return _currentRound; }
		override string toString() {
			return format("%d,%s,%d", _currentRound,
					to!string(_winningBid),_winningAgent.ID);
		}

	private:
		immutable int _numRounds;
		immutable int _currentRound;
		const Agent _winningAgent;
		Bid _winningBid;
}

class StartInformation : ProgressInformation {
	this (int numRounds, Bid winningBid=new NullBid, int currentRound=0) {
		super(numRounds,winningBid,currentRound);
	}
	@property override InfoType infoT() const { return InfoType.start; }
	override string toString() {
		return format("Starting a run with %d rounds\n",_numRounds) ~
					 format("round,winning bid,winning agent id");
	}
}
class EndInformation : ProgressInformation {
	this (int numRounds, Bid winningBid, int currentRound, Agent winningAgent) in {
		assert(numRounds == currentRound+1);
	} body {
		super(numRounds, winningBid, currentRound, winningAgent);
	}
	@property override InfoType infoT() const { return InfoType.end; }
}
