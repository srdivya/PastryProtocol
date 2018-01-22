defmodule Pastry do
    use GenServer
    def start_link(numNodes, numRequests) do
        GenServer.start_link(__MODULE__, %{numNodes: String.to_integer(numNodes), numRequests: String.to_integer(numRequests), pastry_ids: [], terminated_requests: 0, total_count: 0}, [name: :PastryMain])
        startOne(numNodes)
        :timer.sleep(:infinity)
    end
    def init(state) do
        {:ok, state}
    end
    def startOne(numNodes) do
        numNodes = String.to_integer(numNodes)
        node_id = :crypto.hash(:md5, "#{numNodes}") |> Base.encode16()
        PastryNode.start_link(node_id)
        pastry_ids = joinNodes(numNodes - 1, [node_id])
        pastry_ids = Enum.sort(pastry_ids)
        rand_pastry_id = Enum.at(pastry_ids, 0)
        GenServer.cast(:PastryMain, {:updatePastryID, pastry_ids})  #store sorted pastry IDS in state
        PastryNode.updateLeafSet(rand_pastry_id, pastry_ids, 0)
    end
    def handle_cast({:updatePastryID, pastry_ids}, state) do
        new_state = Map.put(state, :pastry_ids, pastry_ids)
        # IO.puts "up ids"
        #IO.inspect state
        {:noreply, new_state}
    end
    def joinNodes(numNodes, pastry_ids) do #rename nicely
        if(numNodes > 0) do
            node_id = :crypto.hash(:md5, "#{numNodes}") |> Base.encode16()
            PastryNode.start_link(node_id)
            pastry_ids = Enum.concat([node_id], pastry_ids)
            msg = PastryNode.findNeighbours( node_id, pastry_ids)
            if (msg == {:ok}) do
                joinNodes(numNodes - 1, pastry_ids)
            end
        else
            pastry_ids
        end
    end
    def leafUpdated() do
        msg = GenServer.cast(:PastryMain, {:leafUpdateDone})
    end
    def handle_cast({:leafUpdateDone}, state) do
        {:numRequests, numRequests} = Enum.at(state, 1)
        {:numNodes, numNodes} = Enum.at(state, 0)
        {:pastry_ids, pastry_ids} = Enum.at(state, 2)
        {:terminated_requests, no_terminated} = Enum.at(state, 3)
        r1 = 1..numRequests
        r2 = 0..numNodes-1
        range_outer = Enum.to_list(r1)
        range_inner = Enum.to_list(r2)
        Enum.each(range_outer, fn (no_req) ->
            range = 1..10000
            rand_val = Enum.random(Enum.to_list(range))
            rand_msg = :crypto.hash(:md5, "#{rand_val}") |> Base.encode16()
            destination = findClosestNode(rand_msg, pastry_ids, 0)
            Enum.each(range_inner, fn (no_nodes) ->
                pastry_id = Enum.random(pastry_ids)
                PastryNode.route(pastry_id, destination, 0, pastry_ids)
            end)
            :timer.sleep(1000)
        end)
        {:noreply, state}
    end
    def updateHopCount(hop_count) do
        #IO.puts "hop = #{hop_count}"
        GenServer.cast(:PastryMain, {:update_hop_data, hop_count})
        #:timer.sleep(1000)
    end
    def handle_cast({:update_hop_data, hop_count}, state) do
        {:numRequests, numRequests} = Enum.at(state, 1)
        {:numNodes, numNodes} = Enum.at(state, 0)
        {:terminated_requests, no_done} = Enum.at(state, 3)
        {:total_count, total_count} = Enum.at(state, 4)
        no_done = no_done + 1
        if(no_done <= (numRequests * numNodes)) do
            if(no_done == (numRequests * numNodes)) do
                #IO.puts "numreq = #{numRequests}"
                avg = total_count/(numRequests * numNodes)
                IO.puts "Average hops = #{avg}"
                Process.exit(Process.whereis(:PastryMain), :kill)
            else
                #IO.puts "else hop_count + total_count = #{hop_count + total_count} numReq = #{no_done}"
                state = Map.put(state, :total_count, hop_count + total_count)
                state = Map.put(state, :terminated_requests, no_done)
            end
        end
        {:noreply, state}
    end
    def findClosestNode(msg_hash, pastry_ids, index) do
        if(index < length(pastry_ids)) do
            {node_int,_} = Integer.parse(Enum.at(pastry_ids, index), 16)
            {msg_int, _} = Integer.parse(msg_hash, 16)
            if(node_int <= msg_int) do
                findClosestNode(msg_hash, pastry_ids, index + 1)
            else
                {old_node_int, _} = Integer.parse(Enum.at(pastry_ids, index - 1), 16)
                if(abs(node_int - msg_int) >= abs(old_node_int - msg_int)) do
                    Enum.at(pastry_ids, index - 1)
                else
                    Enum.at(pastry_ids, index)
                end
            end
        end
    end
end