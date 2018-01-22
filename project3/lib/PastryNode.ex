defmodule PastryNode do
    use GenServer
    def start_link(node_id) do
        table = List.duplicate(List.duplicate("nil", 16), 32)
        {:ok, pid} = GenServer.start_link(__MODULE__, %{lesser_leafset: [], larger_leafset: [], routing_table: table, node_id: node_id}, [name: :"#{node_id}"])
    end
    def init(state) do
        {:ok, state}
    end
    def findNeighbours(node_id, pastry_ids) do
        msg = GenServer.cast(:"#{node_id}", {:setRouting, pastry_ids})
        {:ok}
    end
    def handle_cast({:setRouting, pastry_ids}, state) do
        {:node_id, node_id} = Enum.at(state, 2)
        {:routing_table, routing_table} = Enum.at(state, 3)
        pastry_ids = pastry_ids -- [node_id]
        Enum.each(pastry_ids, fn(x) ->
            GenServer.cast(:"#{node_id}", {:set_in_table, node_id, x})
        end)
        Enum.each(pastry_ids, fn x ->
            PastryNode.updateRoutingTable(x, node_id, routing_table)
        end)
        {:noreply, state}
    end
    def handle_cast({:set_in_table, node_id, x}, state) do
        {:routing_table, routing_table} = Enum.at(state, 3)
        i = get_prefix_length(node_id, x, 0)
        val = String.at(x, i)
        j = cond do
            val == "A" -> 10
            val == "B" -> 11
            val == "C" -> 12
            val == "D" -> 13
            val == "E" -> 14
            val == "F" -> 15
            true -> String.to_integer(val)
        end
        if (routing_table |> Enum.at(i) |> Enum.at(j) == "nil") do
            list_at = Enum.at(routing_table, i)
            list_at = List.delete_at(list_at, j)
            list_at = List.insert_at(list_at, j, x)
            routing_table = List.delete_at(routing_table, i)
            routing_table = List.insert_at(routing_table, i, list_at)
        end
        state = Map.put(state, :routing_table, routing_table)
        {:noreply, state}
    end
    def get_prefix_length(nodeA, nodeB, len) do
        if (String.slice(nodeA, 0, 1) == String.slice(nodeB, 0, 1)) do
            nodeA = String.slice(nodeA, 1..String.length(nodeA))
            nodeB = String.slice(nodeB, 1..String.length(nodeB))
            get_prefix_length(nodeA, nodeB, len + 1)
        else #prefix mismatch so return length
            len
        end
    end
    def updateRoutingTable(own_node_id, new_node, new_routing_table) do
        GenServer.cast(:"#{own_node_id}", {:update_table, new_node, new_routing_table})
    end
    def handle_cast({:update_table, new_node, new_table}, state) do
        {:node_id, node_id} = Enum.at(state, 2)
        {:routing_table, own_table} = Enum.at(state, 3)
        range = 0..31
        temp_list = Enum.to_list(range)
        GenServer.cast(:"#{node_id}", {:set_in_table, node_id, new_node})
        Enum.each(temp_list, fn i ->
            range1 = 0..15
            temp_list1 = Enum.to_list(range1)
            Enum.each(temp_list1, fn j -> 
                new_val = new_table |> Enum.at(i) |> Enum.at(j)
                if (new_val != "nil") do
                    if (!Enum.member?(own_table, new_val)) do
                        GenServer.cast(:"#{node_id}", {:set_in_table, node_id, new_val})
                    end
                end
            end)
            
        end) 
        {:noreply, state}
    end
    def updateLeafSet(rand_pid, pastry_ids, count) do
        if(count <= length(pastry_ids)) do
            GenServer.cast(:"#{rand_pid}", {:update_Leaf, pastry_ids, count})
            pid = rand_pid
            new_list = pastry_ids -- [pid]
            next_rand_pid = Enum.at(pastry_ids, count + 1)
            response = PastryNode.updateLeafSet(next_rand_pid, pastry_ids, count + 1)
            if(response == :done) do
                #IO.puts "all joined"
                Pastry.leafUpdated()
            end
        else
            :done
        end
    end
    def handle_cast({:update_Leaf, pastry_ids, index}, state) do
        {:node_id, node_id} = Enum.at(state, 2)
        {:lesser_leafset, lesser_leafset} = Enum.at(state, 1)
        {:larger_leafset, larger_leafset} = Enum.at(state, 0)
        new_start = 0
        new_end = 0
        new_start = if (index - 8 < 0), do: 0, else: index - 8
        lesser_leafset = addToLeafSet(pastry_ids, new_start, index, new_start, lesser_leafset)
        new_end = if (index + 8 > length(pastry_ids)), do: length(pastry_ids), else: index + 8
        larger_leafset = addToLeafSet(pastry_ids, index + 1, new_end, index + 1, larger_leafset)
        state = Map.put(state, :lesser_leafset, lesser_leafset)
        state = Map.put(state, :larger_leafset, larger_leafset)
        :timer.sleep(1000)
        {:noreply, state}
    end
    def addToLeafSet(pastry_ids, start_index, stop_index, index, leafSet) do
        if (index >= start_index) do
            if (index < stop_index) do
                leafSet = leafSet ++ [Enum.at(pastry_ids, index)]
                addToLeafSet(pastry_ids, start_index, stop_index, index + 1, leafSet)
            else
                leafSet
            end
        end
    end
    def route(pastry_id, destination, hop_count, pastry_ids) do
        GenServer.cast(:"#{pastry_id}", {:forward_msg, destination, hop_count, pastry_ids})
    end
    def handle_cast({:forward_msg, destination, hop_count, pastry_ids}, state) do
        {:larger_leafset, larger_leafset} = Enum.at(state, 0)
        {:lesser_leafset, lesser_leafset} = Enum.at(state, 1)
        {:routing_table, routing_table} = Enum.at(state, 3)
        {:node_id, node_id} = Enum.at(state, 2)
        if (node_id == destination) do
            Pastry.updateHopCount(hop_count)
        else
            #checking in leafsets
            leafset = lesser_leafset ++ larger_leafset
            lowest_leaf = List.first(leafset)
            largest_leaf = List.last(leafset)
            if(destination >= lowest_leaf && destination <= largest_leaf) do
                if(Enum.member?(leafset, destination)) do
                    Pastry.updateHopCount(hop_count+1)
                    {:noreply, state}
                else
                    next_hop = findClosestNode(destination, leafset, 0)
                end
            else
                #check in routing table next
                i = get_prefix_length(destination, node_id, 0)
                val = String.at(destination, i)
                j = cond do
                    val == "A" -> 10
                    val == "B" -> 11
                    val == "C" -> 12
                    val == "D" -> 13
                    val == "E" -> 14
                    val == "F" -> 15
                    true -> String.to_integer(val)
                end
                #IO.puts "ij = #{i} #{j}"
                routing_node = routing_table |> Enum.at(i) |> Enum.at(j)
                #IO.inspect routing_node
                if(routing_node != "nil") do
                    next_hop = routing_node
                else
                    if(destination != "") do
                        if(destination > node_id) do
                            next_hop = largest_leaf
                        else
                            next_hop = lowest_leaf
                        end
                    end
                end
            end
        end
        PastryNode.route(:"#{next_hop}", destination, hop_count + 1, pastry_ids)
        {:noreply, state}
    end
    def findClosestNode(msg_hash, leafSet, index) do
        if(Enum.at(leafSet, index) != nil) do
            {node_int,_} = Integer.parse(Enum.at(leafSet, index), 16)
            {msg_int, _} = Integer.parse(msg_hash, 16)
            if(node_int <= msg_int) do
                findClosestNode(msg_hash, leafSet, index + 1)
            else
                {old_node_int, _} = Integer.parse(Enum.at(leafSet, index - 1), 16)
                if(abs(node_int - msg_int) >= abs(old_node_int - msg_int)) do
                    Enum.at(leafSet, index - 1)
                else
                    Enum.at(leafSet, index)
                end
            end
        end
    end
    def findInNetwork(destination, pastry_ids, index, prev_diff, prev_len, pastry_node) do
        if(index < length(pastry_ids)) do
            this_pastry_node = Enum.at(pastry_ids, index)
            len = get_prefix_length(destination, this_pastry_node, 0)
            {this_pastry_node_int, _} = Integer.parse(this_pastry_node, 16)
            if(len > prev_len) do
                diff = abs(destination - this_pastry_node_int)
                if(diff < prev_diff) do
                    findInNetwork(destination, pastry_ids, index + 1, diff, len, Enum.at(pastry_ids, index))
                else
                    findInNetwork(destination, pastry_ids, index + 1, prev_diff, len, Enum.at(pastry_ids, index - 1))
                end
            else
                findInNetwork(destination, pastry_ids, index + 1, prev_diff, prev_len, pastry_node)
            end
        else
            pastry_node
        end
    end
end