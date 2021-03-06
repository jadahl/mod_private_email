%%%----------------------------------------------------------------------
%%% File    : mod_private_email.erl
%%% Author  : Jonas Ådahl <jadahl@gmail.com>
%%% Purpose : Provides an API for privately storing E-mail address.
%%% Created : 20 Feb 2011 by Jonas Ådahl <jadahl@gmail.com>
%%%
%%%
%%% Copyright (C) 2011-2013   Jonas Ådahl
%%%
%%% This program is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU Affero General Public License as
%%% published by the Free Software Foundation, either version 3 of the
%%% License, or (at your option) any later version.
%%% 
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU Affero General Public License for more details.
%%% 
%%% You should have received a copy of the GNU Affero General Public
%%% License along with this program.
%%%
%%% If not, see <http://www.gnu.org/licenses/>.
%%% 
%%%----------------------------------------------------------------------

-module(mod_private_email).
-author('jadahl@gmail.com').

-export([
        % gen_mod
        start/2, stop/1,

        % API
        set_email/2,
        get_email/1,
        delete_email/1,

        % User events
        user_removed/2,
        user_registered/2,

        % Ad-hoc commands
        private_email_items/4,
        private_email_commands/4,

        % mod_restful_register events
        mod_restful_register_registered/4,

        % mod_restful API
        process_rest/1
    ]).

-behaviour(gen_mod).
-behaviour(gen_restful_api).

-include_lib("ejabberd/include/ejabberd.hrl").
-include_lib("ejabberd/include/jlib.hrl").
-include_lib("ejabberd/include/adhoc.hrl").

-include_lib("ejabberd/include/mod_restful.hrl").

-record(private_email, {
        user :: {string(), string()},
        email :: string()
    }).

%
% gen_mod API
%

start(Host, _Opts) ->
    mnesia:create_table(private_email, [
            {disc_copies, [node()]},
            {attributes, record_info(fields, private_email)}
        ]),

    update_table(),

    % user event hooks
    ejabberd_hooks:add(remove_user, Host, ?MODULE, user_removed, 50),
    ejabberd_hooks:add(register_user, Host, ?MODULE, user_registered, 50),

    % ad-hoc hooks
    ejabberd_hooks:add(adhoc_local_items, Host,
                       ?MODULE, private_email_items, 50),
    ejabberd_hooks:add(adhoc_local_commands, Host,
                       ?MODULE, private_email_commands, 50),

    % mod_restful_register hooks
    ejabberd_hooks:add(mod_restful_register_registered, Host,
                       ?MODULE, mod_restful_register_registered, 50),

    ok.

stop(Host) ->
    % mod_restful_register hooks
    ejabberd_hooks:delete(mod_restful_register_registered, Host,
                          ?MODULE, mod_restful_register_registered, 50),

    % ad-hoc hooks
    ejabberd_hooks:delete(adhoc_local_commands, Host, ?MODULE,
                          private_email_commands, 50),
    ejabberd_hooks:delete(adhoc_local_items, Host,
                          ?MODULE, private_email_items, 50),

    % user event hooks
    ejabberd_hooks:delete(remove_user, Host, ?MODULE, user_removed, 50),
    ejabberd_hooks:delete(register_user, Host, ?MODULE, user_registered, 50),

    ok.

%
% Internal
%

-define(T(L, S), translate:translate(L, S)).

update_table() ->
    Fields = record_info(fields, private_email),
    case mnesia:table_info(private_email, attributes) of
        Fields ->
            ok;
        _ ->
            error_logger:info_msg("Recreating private_email table"),
            mnesia:transform_table(private_email, ignore, Fields)
    end.

%
% API
%

-spec set_email(#jid{}, string()) -> ok | {error, atom()}.
set_email(#jid{} = JID, Email) ->
    case re:run(Email, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+") of
        {match, _} ->
            #jid{luser = User, lserver = Server} = JID,
            F = fun() ->
                mnesia:write(#private_email{user = {User, Server},
                                            email = Email})
            end,
            case mnesia:transaction(F) of
                {atomic, _} -> ok;
                {aborted, _Reason} ->
                    error_logger:error_msg("Couldnt set private Email '~p' for '~p': ~p",
                                           [Email, JID, _Reason]),
                    {error, aborted}
            end;
        _ ->
            {error, invalid_email}
    end.

-spec get_email(#jid{}) -> string() | {error, atom()}.
get_email(JID) ->
    try
        #jid{luser = User, lserver = Server} = JID,
        case mnesia:dirty_read(private_email, {User, Server}) of
            [#private_email{email = Email}] -> io:format("got email ~p from ~p~n", [Email, JID]),Email;
            _                               -> <<"">>
        end
    catch
        {'EXIT', _Reason} ->
            error_logger:error_msg("Error when retrieving Email for '~p'", [JID]),
            {error, mnesia}
    end.

delete_email(JID) ->
    #jid{luser = User, lserver = Server} = JID,
    F = fun() ->
        mnesia:delete({private_email, {User, Server}})
    end,
    mnesia:transaction(F).

%
% User events
%

user_removed(User, Server) ->
    JID = jlib:make_jid(User, Server, <<"">>),
    delete_email(JID).

user_registered(User, Server) ->
    % Clear previous entry, if one exists
    user_removed(User, Server).

%
% Ad-Hoc commands
%

-define(NODE_TO_ITEM(Lang, Server, Node),
    {xmlelement, "item",
        [{"jid", Server},
            {"node", Node},
            {"name", title(Lang, Node)}],
        []}).

-define(PRIVATE_EMAIL(Method), "private_email#" ++ Method).

title(Lang, ?PRIVATE_EMAIL("set")) ->
    ?T(Lang, "Store E-mail address without making it publicly visible");
title(Lang, ?PRIVATE_EMAIL("clear")) ->
    ?T(Lang, "Clear private E-mail").

private_email_items(Acc, From, #jid{lserver = _LServer, server = Server} = _To,
                    Lang) ->
    Nodes = case acl:match_rule(_LServer, ?MODULE, From) of
        allow ->
            [?NODE_TO_ITEM(Lang, Server, ?PRIVATE_EMAIL("set")),
             ?NODE_TO_ITEM(Lang, Server, ?PRIVATE_EMAIL("clear"))];
        deny ->
            []
    end,

    case Nodes of
        [] ->
            Acc;
        _ ->
            Items = case Acc of
                {result, AccItems} -> AccItems;
                _                  -> []
            end,
            {result, Items ++ Nodes}
    end.

private_email_commands(Acc, From, #jid{lserver = LServer} = _To,
                       #adhoc_request{node = Node} = Request) ->
    case lists:member(Node, [?PRIVATE_EMAIL("set"),
                             ?PRIVATE_EMAIL("clear")]) of
        true ->
            case acl:match_rule(LServer, ?MODULE, From) of
                deny  -> {error, ?ERR_FORBIDDEN};
                allow -> private_email_command(From, Request)
            end;
        _ ->
            Acc
    end.

generate_form(Lang, From) ->
    OldEmail = get_email(From),
    error_logger:info_msg("old email ~p", [OldEmail]),
    {xmlelement, "x",
     [{"xmlns", ?NS_XDATA},
      {"type", "form"}],
     [{xmlelement, "title", [],
       [{xmlcdata, title(Lang, ?PRIVATE_EMAIL("set"))}]},
      {xmlelement, "field",
       [{"type", "text-single"},
        {"var", "email"},
        {"label", ?T(Lang, "Email")}],
       [{xmlelement, "value", [],
         [{xmlcdata, OldEmail}]}]}]}.

handle_set_fields(Fields, From, #adhoc_request{lang = Lang} = Request) ->
    case proplists:get_value("email", Fields) of
        undefined ->
            {error, ?ERR_BAD_REQUEST};
        Email ->
            Notes = case set_email(From, Email) of
                ok ->
                    [{"info", ?T(Lang, "Email has been set.")}];
                {error, _Reason} ->
                    error_logger:error_message("Could not set private email '~p'", [Email]),
                    [{"error", ?T(Lang, "Failed to set Email.")}]
            end,

            Response = #adhoc_response{status = completed,
                                       notes = Notes},
            adhoc:produce_response(Request, Response)
    end.

command_set(From, #adhoc_request{lang = Lang,
                                 action = Action,
                                 xdata = XData} = Request) ->
    Execute = lists:member(Action, ["", "execute", "complete"]),
    if
        Execute, XData == false ->
            Form = generate_form(Lang, From),
            adhoc:produce_response(Request,
                                   #adhoc_response{status = executing,
                                                   elements = [Form]});
        Execute, XData /= false ->
            case jlib:parse_xdata_submit(XData) of
                invalid -> {error, ?ERR_BAD_REQUEST};
                Fields  -> handle_set_fields(Fields, From, Request)
            end;
        true ->
            {error, ?ERR_BAD_REQUEST}
    end.

command_clear(From, #adhoc_request{lang = Lang,
                                   action = Action,
                                   xdata = XData} = Request) ->
    Execute = lists:member(Action, ["", "execute", "complete"]),
    if
        Execute, XData == false ->
            delete_email(From),
            Notes =[{"info", ?T(Lang, "Email has been cleared.")}],
            Response = #adhoc_response{lang = Lang,
                                       notes = Notes,
                                       status = completed},
            adhoc:produce_response(Request, Response);
        true ->
            {error, ?ERR_BAD_REQUEST}
    end.

private_email_command(From, #adhoc_request{node = Node,
                                           action = Action} = Request) ->
    if
        Action == "cancel" ->
            adhoc:produce_response(Request,
                                   #adhoc_response{status = cancelled});
        true ->
            case Node of
                ?PRIVATE_EMAIL("set")   -> command_set(From, Request);
                ?PRIVATE_EMAIL("clear") -> command_clear(From, Request);
                _                       -> {error, ?ERR_BAD_REQUEST}
            end
    end.

%
% mod_restful_register
%

mod_restful_register_registered(AccIn, Username, Host, Request) ->
    case gen_restful_api:params([email], Request) of
        [Email] ->
            JID = jlib:make_jid(Username, Host, <<"">>),
            case set_email(JID, Email) of
                ok               -> AccIn;
                {error, _Reason} -> [{private_email, not_set} | AccIn]
            end;
        _ ->
            [{private_email, not_set} | AccIn]
    end.

%
% mod_restful API
%

process_rest(Request) ->
    case gen_restful_api:authorize_key_request(Request) of
        allow ->
            process(Request);
        _ ->
            {error, not_allowed}
    end.

process(#rest_req{path = [_, <<"change">>],
                  http_request = #request{method = 'POST'}} = Request) ->
    process_change(Request);
process(#rest_req{path = [_, <<"get">>],
                  http_request = #request{method = 'GET'}} = Request) ->
    process_get(Request);
process(_) ->
    {error, not_found}.

if_allowed(Username, Host, Password, Fun) ->
    case gen_restful_api:host_allowed(Host) andalso
         ejabberd_auth:check_password(Username, Host, Password) of
        true ->
            JID = jlib:make_jid(Username, Host, <<"">>),
            Fun(JID);
        _  ->
            {error, not_allowed}
    end.

process_change(Request) ->
    case gen_restful_api:params([username, host, password, new_email],
                                Request) of
        [Username, Host, Password, Email] ->
            Fun = fun(JID) ->
                      ok = set_email(JID, Email),
                      {simple, ok}
                  end,
            if_allowed(Username, Host, Password, Fun);
        _ ->
            {error, bad_request2}
    end.

process_get(Request) ->
    case gen_restful_api:params([username, host], Request) of
        [Username, Host] ->
            case gen_restful_api:host_allowed(Host) of
                true ->
                    JID = jlib:make_jid(Username, Host, <<"">>),
                    case get_email(JID) of
                        R when is_list(R) or is_binary(R) -> {simple, R};
                        {error, _} = Error                -> Error
                    end
            end;
        _ ->
            {error, bad_request1}
    end.

