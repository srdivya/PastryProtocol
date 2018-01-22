Project 3 - Pastry Protocol

Team Members:
Divya Saroja Rengasamy:  3338-1372
Riddhima Arora: 1941-1995

What is working?

Node network
- Our program is implemented to join nodes as and when they come. 
- The nodeids is hashed using md5 to a 32 bit hexadecimal string
- We have taken b = 4
- We have a 16 by 32 routing table for each nodeid and leaf set of size 16 with 8 nodeids having a smaller value and 8 larger value than the nodeid 
- We tested the join network for 1000 nodes with the correct routing table and leaf sets.

Routing API
- We have implemented the API by fixing a destination id chosen from the set of nodeids in the nodeidspace
- We are routing the number of requests to the number of nodes and following the lgorithm for hops
- The average number of hops comes out to be less than or equalt to logN/log 16

The largest Network
We tested for a maximum of 10000 nodes with 1 requests with average hops equal to 3.31. We could have tested for more number of nodes but it would have taken a lot of time.
Other values tested were 
Nodes    Requests    Avg_Hops
1000	 10	     2.4098
1500	 10          2.6
2000	 10 	     2.74
2500	 10	     2.75