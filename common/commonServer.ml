(* Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA *)
(*
    This server is part of mldonkey.

    mldonkey is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    mldonkey is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mldonkey; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Printf2
open CommonOptions
open CommonGlobals
open CommonNetwork
open Options
open CommonUser
open CommonTypes
  
type 'a server_impl = {
    mutable impl_server_update : int;
    mutable impl_server_state : CommonTypes.host_state;
    mutable impl_server_num : int;
    mutable impl_server_sort : int;
    mutable impl_server_val : 'a;
    mutable impl_server_ops : 'a server_ops;
  }

and 'a server_ops = {
    mutable op_server_network : network;
    mutable op_server_to_option : ('a -> (string * option_value) list);
    mutable op_server_remove : ('a -> unit);
    mutable op_server_info : ('a -> GuiTypes.server_info);
    mutable op_server_sort : ('a -> int);
    mutable op_server_connect : ('a -> unit);
    mutable op_server_disconnect : ('a -> unit);
    mutable op_server_users : ('a -> user list);
    mutable op_server_query_users : ('a -> unit);
    mutable op_server_find_user : ('a -> string -> unit);
    mutable op_server_cid : ('a -> Ip.t);
  }

let ni n m = 
  let s = Printf.sprintf "Server.%s not implemented by %s" 
      m n.network_name in
  lprint_string s; lprint_newline ();
  s
  
let fni n m =  failwith (ni n m)
let ni_ok n m = ignore (ni n m)
  
  
let as_server  (server : 'a server_impl) =
  let (server : server) = Obj.magic server in
  server

let as_server_impl  (server : server) =
  let (server : 'a server_impl) = Obj.magic server in
  server

    
let  dummy_server_impl = {
    impl_server_update = 1;
    impl_server_state = NewHost;
    impl_server_num = 0;
    impl_server_sort = 0;
    impl_server_val = 0;
    impl_server_ops = Obj.magic None;
  }

let dummy_server = as_server dummy_server_impl


let server_num s =
  let s = as_server_impl s in
  s.impl_server_num
  
module H = Weak2.Make(struct
      type t = server
      let hash s = Hashtbl.hash (server_num s)
      
      let equal x y = 
        (server_num x) = (server_num y)
    end)

let server_counter = ref 0
let servers_by_num = H.create 1027
  
let _ = 
  Heap.add_memstat "CommonServer" (fun buf ->
      let counter = ref 0 in
      H.iter (fun _ -> incr counter) servers_by_num;
      Printf.bprintf buf "  servers: %d\n" !counter;
  )

let server_must_update s =
(*  lprintf "server_must_update ?"; lprint_newline (); *)
  let impl = as_server_impl s in
  if impl.impl_server_update <> 0 then
    CommonEvent.add_event (Server_info_event s);
  impl.impl_server_update <- 0
  
let server_must_update_state s =
  let impl = as_server_impl s in
  if impl.impl_server_update > 0 then
    begin
      impl.impl_server_update <- - impl.impl_server_update;
      CommonEvent.add_event (Server_info_event s);
(*      lprintf "server_must_update YES"; lprint_newline (); *)
    end


    
let server_update_num impl =
  let server = as_server impl in
  incr server_counter;
  impl.impl_server_num <- !server_counter;
  server_must_update server;
  H.add servers_by_num server

let server_to_option (server : server) =
  let server = as_server_impl server in
  server.impl_server_ops.op_server_to_option server.impl_server_val

let server_network (server : server) =
  let server = as_server_impl server in
  server.impl_server_ops.op_server_network

let server_to_option server =
  let server = as_server_impl server in
  server.impl_server_ops.op_server_to_option server.impl_server_val


let server_info (server : server) =
  let server = as_server_impl server in
  server.impl_server_ops.op_server_info server.impl_server_val

let server_find_user s u =
  let s = as_server_impl s in
  s.impl_server_ops.op_server_find_user s.impl_server_val u

let server_query_users s =
  let s = as_server_impl s in
  s.impl_server_ops.op_server_query_users s.impl_server_val

let server_users s =
  let s = as_server_impl s in
  s.impl_server_ops.op_server_users s.impl_server_val

let server_cid s =
  let s = as_server_impl s in
  s.impl_server_ops.op_server_cid s.impl_server_val
  
let servers_ops = ref []
let new_server_ops network =
  let s = {
      op_server_network =  network;
      op_server_remove = (fun _ -> ni_ok network "server_remove");
(*    op_server_print = (fun _ _ -> ni_ok network "server_print"); *)
      op_server_to_option = (fun _ -> fni network "server_to_option");
      op_server_info = (fun _ -> fni network "server_info");
      op_server_sort = (fun _ -> ni_ok network "server_sort"; 0);
      op_server_connect = (fun _ -> ni_ok network "server_connect");
      op_server_disconnect = (fun _ -> ni_ok network "server_disconnect");
      op_server_find_user = (fun _ -> fni network "find_user");
      op_server_query_users = (fun _ -> ni_ok network "query_users");
      op_server_users = (fun _ -> fni network "users");
      op_server_cid = (fun _ -> fni network "cid");
    } in
  let ss = (Obj.magic s : int server_ops) in
  servers_ops := (ss, { ss with op_server_network = s.op_server_network })
  :: ! servers_ops;
  s
  

let check_server_implementations () =
  lprintf "\n----- Methods not implemented for CommonServer ----\n";
  lprint_newline ();
  List.iter (fun (c, cc) ->
      let n = c.op_server_network.network_name in
      lprintf "\n  Network %s\n" n; lprint_newline ();
      if c.op_server_remove == cc.op_server_remove then 
        lprintf "op_server_remove\n";
      if c.op_server_to_option == cc.op_server_to_option then
        lprintf "op_server_to_option\n";
      if c.op_server_info == cc.op_server_info then
        lprintf "op_server_info\n";
      if c.op_server_sort == cc.op_server_sort then
        lprintf "op_server_sort\n";
      if c.op_server_connect == cc.op_server_connect then
        lprintf "op_server_connect\n";
      if c.op_server_disconnect == cc.op_server_disconnect then
        lprintf "op_server_disconnect\n";
      if c.op_server_find_user == cc.op_server_find_user then
        lprintf "op_server_find_user\n";
      if c.op_server_query_users == cc.op_server_query_users then
        lprintf "op_server_query_users\n";
      if c.op_server_users == cc.op_server_users then
        lprintf "op_server_users\n";
      if c.op_server_cid == cc.op_server_cid then
        lprintf "op_server_cid\n";
  ) !servers_ops;
  lprint_newline () 

let server_find (num : int) = 
  H.find servers_by_num  (as_server { dummy_server_impl with
      impl_server_num = num })
  
let server_connect s =
  let server = as_server_impl s in
  server.impl_server_ops.op_server_connect server.impl_server_val
  
let server_disconnect s =
  let server = as_server_impl s in
  server.impl_server_ops.op_server_disconnect server.impl_server_val


let server_state c =
  let impl = as_server_impl c in
  impl.impl_server_state

let server_num c =
  let impl = as_server_impl c in
  impl.impl_server_num
  
let set_server_state c state =
  let impl = as_server_impl c in
  if impl.impl_server_state <> state then begin
      impl.impl_server_state <- state;
      server_must_update_state c
    end

let server_sort () = 
  let list = ref [] in
  H.iter (fun s ->
      let impl = as_server_impl s in
      match impl.impl_server_state with
        RemovedHost -> ()
      | _ ->
          list := s :: !list;
          impl.impl_server_sort <- 
            (try impl.impl_server_ops.op_server_sort impl.impl_server_val
            with _ -> 0);
  ) servers_by_num;
  Sort.list (fun s1 s2 -> 
      (as_server_impl s1).impl_server_sort >= (as_server_impl s2).impl_server_sort
  ) !list

let server_iter f =
  H.iter f servers_by_num
  
  
let com_servers_by_num = servers_by_num  
  
let server_new_user server user =
  user_must_update user;
  CommonEvent.add_event (Server_new_user_event (server, user))

let servers_get_all () =
  let list = ref [] in
  H.iter (fun c ->
      list := (server_num c) :: !list) servers_by_num;
  !list
  
let servers_by_num = ()
  
    
(*  
type server_info = {
    server_num : int;
    server_network : int;
    
    mutable server_ip : Ip.t;
    mutable server_port : int;
    mutable server_score : int;
    mutable server_tags : CommonTypes.tag list;
    mutable server_nusers : int;
    mutable server_nfiles : int;
    mutable server_state : host_state;
    mutable server_name : string;
    mutable server_description : string;
    mutable server_users : int list option;
  } 
    *)

module G = GuiTypes

let server_banner s o =
  let buf = o.conn_buf in
  let info = server_info s in
  Printf.bprintf buf "%s" 
      info.G.server_banner

let server_print_html_header buf =
    html_mods_table_header buf "serversTable" "servers" [ 
		( "1", "srh", "Server number", "#" ) ; 
		( "0", "srh", "Connect|Disconnect", "C/D" ) ; 
		( "0", "srh", "Remove", "Rem" ) ; 
		( "0", "srh", "[Hi]gh or [Lo]w ID", "ID" ) ; 
		( "0", "srh", "Network name", "Network" ) ; 
		( "0", "srh", "Connection status", "Status" ) ; 
		( "0", "srh br", "IP address", "IP address" ) ; 
		( "1", "srh ar", "Number of connected users", "Users" ) ; 
		( "1", "srh ar br", "Number of files indexed on server", "Files" ) ; 
		( "0", "srh", "Server name", "Name" ) ; 
		( "0", "srh", "Server details", "Details" ) ]  
  
let server_print s o =
  let impl = as_server_impl s in
  let n = impl.impl_server_ops.op_server_network in
  try
    let info = server_info s in
    let buf = o.conn_buf in
	
	if use_html_mods o then begin
	let snum = (server_num s) in

    Printf.bprintf buf "
    \\<td class=\\\"srb\\\" %s \\>%d\\</td\\>
    %s
    %s
    \\<td class=\\\"sr\\\" %s\\</td\\>
    \\<td class=\\\"sr\\\"\\>%s\\</td\\>
    \\<td class=\\\"sr\\\"\\>%s\\</td\\>
    \\<td class=\\\"sr br\\\"\\>%s:%d\\</td\\>
    \\<td class=\\\"sr ar\\\"\\>%d\\</td\\>
    \\<td class=\\\"sr ar br\\\"\\>%d\\</td\\>
    \\<td class=\\\"sr\\\"\\>%s\\</td\\>
    \\<td class=\\\"sr\\\"\\>%s\\</td\\>\\</tr\\>\n"
	  (
        Printf.sprintf "%s"
        (match impl.impl_server_state with
        Connected _ -> Printf.sprintf "title=\\\"Server Banner\\\" 
						onMouseOver=\\\"mOvr(this);\\\"
						onMouseOut=\\\"mOut(this);\\\"
						onClick=\\\"location.href='/submit?q=server_banner+%d'\\\"" snum
        | _ -> "")
	  )
	  snum
      (
        Printf.sprintf
        "\\<TD class=\\\"srb\\\" onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\" title=\\\"Disconnect|Connect\\\"
        onClick=\\\"parent.fstatus.location.href='/submit?q=%s+%d'\\\"\\>%s\\</TD\\>"
      (match impl.impl_server_state with
        NotConnected _ -> "c"
      | _ -> "x")
      snum
      (match impl.impl_server_state with
        NotConnected _ -> "Conn"
      | _ -> "Disc")
      )
      (
        Printf.sprintf
        "\\<TD class=\\\"srb\\\" onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\" title=\\\"Remove server\\\"
        onClick=\\\"parent.fstatus.location.href='/submit?q=rem+%d'\\\"\\>Rem\\</TD\\>"
      snum
      )
      
      (if n.network_name = "Donkey" then 
        begin
            match impl.impl_server_state with
            Connected _ -> begin 
                        let cid = (server_cid s) in
                        if Ip.valid cid then Printf.sprintf 
                        "title=\\\"HighID: %s = %s %s\\\" \\>%s" 
                        (Int64.to_string (Ip.to_int64 (Ip.rev cid)))  
						(Ip.to_string cid) 
						(if !!set_client_ip <> cid then Printf.sprintf "(clientIP: %s)" (Ip.to_string !!set_client_ip) 
						 else "") 
						"Hi"
                        else Printf.sprintf "title=\\\"LowID: %s\\\" \\>%s" 
                        (Int64.to_string (Ip.to_int64 (Ip.rev cid))) "Lo"
                        end
        | _ -> "\\>"

       end else "\\>" )
      
      n.network_name
   (string_of_connection_state impl.impl_server_state)
      (string_of_addr info.G.server_addr) 
	  info.G.server_port
	  info.G.server_nusers
	  info.G.server_nfiles
      info.G.server_name
      info.G.server_description

	end
   else
	begin
          
        Printf.bprintf buf "[%s %-5d] %s:%-5d %-20s %-20s"
          n.network_name
          (server_num s)
        (string_of_addr info.G.server_addr) info.G.server_port
          info.G.server_name
          info.G.server_description
        ;
(*
  List.iter (fun t ->
      Printf.bprintf buf "%-3s "
        (match t.tag_value with
          String s -> s
            | Uint32 i -> Int32.to_string i
        | Fint32 i -> Int32.to_string i
        | _ -> "???"
      )
) info.G.server_tags;
  *)
        Printf.bprintf buf " %6d %7d %s" info.G.server_nusers info.G.server_nfiles
          (string_of_connection_state impl.impl_server_state); 
        Buffer.add_char buf '\n'
      end;
    
  with e -> 
      lprintf "Exception %s in CommonServer.server_print"
        (Printexc2.to_string e); lprint_newline () 
      
