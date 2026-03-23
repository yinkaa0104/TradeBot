
 TradeBot: Gamified Trading Competition Platform

A decentralized smart contract platform built on Stacks (Clarity) that enables users to compete in strategic trading competitions with performancebased prize distributions.

 Overview

TradeBot is a gamified trading competition where participants execute strategic long/short positions across multiple assets, compete on a realtime leaderboard, and win prizes based on their trading performance metrics. The contract handles position lifecycle management, PnL calculations, leverage trading, and transparent leaderboard rankings.

 Features

 Position Management: Open and close long/short positions with configurable leverage up to 10x
 Realistic Trading Simulation: Entry/exit price mechanics with accurate PnL calculations
 Leaderboard System: Realtime ranking based on total PnL and ROI metrics
 Win/Loss Tracking: Comprehensive statistics per trader including win counts and total realized returns
 Leverage Support: Risk management with configurable leverage multipliers (max 10x)
 Prize Pool Management: Ownercontrolled prize distribution and competition funding
 Balance Tracking: Separate margin requirements and available balance management
 Competition Lifecycle: Join, trade, and compete with timelimited or adminended competitions

 Contract Functions

 Public Functions

 joincompetition: Register a new trader with starting capital
 openposition(asset, direction, entryprice, size, leverage): Create a new position
 closeposition(positionid, exitprice): Close an open position and realize PnL
 endcompetition: End competition (owner only)
 addprizepool(amount): Add funds to prize pool (owner only)

 ReadOnly Functions

 gettraderstats(trader): Retrieve trader's balance, PnL, win/loss counts
 getposition(trader, positionid): Get position details (asset, direction, status, PnL)
 getleaderboardscore(trader): Get trader's leaderboard rank and total PnL
 calculateroi(trader): Calculate return on investment percentage
 getcompetitionstatus: Get current competition state and metrics

 Configuration Constants

 STARTINGBALANCE: 10,000,000 microSTX per trader
 MINPOSITIONSIZE: 100,000 microSTX
 MAXLEVERAGE: 10x
 MAXPOSITIONS: 100 per trader
 COMPETITIONDURATION: 144,000 blocks (~1,000 hours)

 Data Structures

 Trader
 balance: Current available balance
 totalpositions: Count of positions opened
 realizedpnl: Total realized profit/loss
 wincount: Number of winning positions
 losscount: Number of losing positions
 joinblock: Block height when joined
 active: Trader status

 Position
 asset: Trading asset identifier
 direction: "long" or "short"
 entryprice: Opening price
 size: Position size in microSTX
 leverage: Leverage multiplier
 openedat: Block height when opened
 isopen: Position status
 pnl: Realized profit/loss

 Error Codes

 Code  Description 

 u1  Not authorized 
 u2  Already joined competition 
 u3  Not joined competition 
 u4  Insufficient balance 
 u5  Invalid position size 
 u6  Position not found 
 u7  Invalid leverage 
 u8  Competition ended 
 u9  No prizes available 
 u10  Invalid direction 
 u11  Position not open 
 u12  Leaderboard score not found 
 u13  Trader not found 

 Testing

Run clarinet check to validate contract syntax and types:
bash
clarinet check


Run unit tests:

shellscript
clarinet test


 Deployment

Deploy to Stacks network:

shellscript
clarinet deploy


 Security Notes

 Position sizing enforced with MINPOSITIONSIZE limits
 Leverage capped at MAXLEVERAGE (10x)
 Balance validation on margin requirements
 Only authorized traders can open/close positions
 Ownercontrolled competition lifecycle


 License

MIT
