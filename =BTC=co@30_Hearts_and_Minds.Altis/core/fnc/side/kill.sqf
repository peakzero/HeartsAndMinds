
/* ----------------------------------------------------------------------------
Function: btc_fnc_side_kill

Description:
    Your objective is to assassinate a man and bring his dogtag to base for identification.

Parameters:
    _taskID - Unique task ID. [String]

Returns:

Examples:
    (begin example)
        [false, "btc_fnc_side_kill"] spawn btc_fnc_side_create;
    (end)

Author:
    Vdauphin

---------------------------------------------------------------------------- */

params [
    ["_taskID", "btc_side", [""]]
];

//// Choose an occupied City \\\\
private _useful = btc_city_all select {_x getVariable ["occupied", false] && !((_x getVariable ["type", ""]) in ["NameLocal", "Hill", "NameMarine"])};

if (_useful isEqualTo []) exitWith {[] spawn btc_fnc_side_create;};

private _city = selectRandom _useful;

//// Randomise position \\\\
private _houses = [getPos _city, 100] call btc_fnc_getHouses;
if (_houses isEqualTo []) exitWith {[] spawn btc_fnc_side_create;};

_houses = _houses apply {[count (_x buildingPos -1), _x]};
_houses sort false;
private _house = objNull;
if (count _houses > 3) then {
    _house = (selectRandom _houses select [0,3]) select 1;
} else {
    _house = _houses select 0 select 1;
};
private _buildingPos = _house buildingPos -1;
private _pos_number = count _buildingPos - 1;
private _pos = _buildingPos select (_pos_number - round random 1);

_city setVariable ["spawn_more", true];

//// Officer
private _group_officer = createGroup btc_enemy_side;
_group_officer setVariable ["no_cache", true];
private _officerType = selectRandom btc_type_units;
private _officer = _group_officer createUnit [_officerType, _pos, [], 0, "CAN_COLLIDE"];
[_group_officer] call btc_fnc_mil_unit_create;

//// Data side mission
private _officerName = name _officer;
[_taskID, 25, objNull, [_officerName, _city getVariable "name"]] call btc_fnc_task_create;
private _kill_taskID = _taskID + "ki";
[[_kill_taskID, _taskID], 26, _officer, [_officerName, _city getVariable "name", _officerType]] call btc_fnc_task_create;

private _group = [];
{
    private _grp = createGroup btc_enemy_side;
    private _unit = _grp createUnit [selectRandom btc_type_units, _x, [], 0, "CAN_COLLIDE"];
    [_unit] joinSilent _grp;
    _group pushBack _grp;
    _grp setVariable ["no_cache", true];
    [_grp] call btc_fnc_mil_unit_create;
} forEach (_buildingPos - [_pos]);

_trigger = createTrigger ["EmptyDetector", _pos];
_trigger setVariable ["group", _group];
_trigger setTriggerArea [20, 20, 0, false];
_trigger setTriggerActivation [str btc_player_side, "PRESENT", true];
_trigger setTriggerStatements ["this", "private _group = thisTrigger getVariable 'group'; {_x setCombatMode 'RED';} forEach _group;", "private _group = thisTrigger getVariable 'group'; {_x setCombatMode 'WHITE';} forEach _group;"];

waitUntil {sleep 5; (_taskID call BIS_fnc_taskCompleted || !alive _officer)};
if (_taskID call BIS_fnc_taskState isEqualTo "CANCELED") exitWith {
    [[], _group + [_group_officer, _trigger]] call btc_fnc_delete;
};

[_kill_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
private _dogTag_taskID = _taskID + "dt";
[[_dogTag_taskID, _taskID], 27, _officer, _officerName] call btc_fnc_task_create;
private _officer_dogtagData = [_officer] call ace_dogtags_fnc_getDogtagData;
private _globalVariableName = format ["btc_%1", _dogTag_taskID];

["ace_dogtags_addDogtagItem", {
    params ["_item", "_dogTagData"];
    _thisArgs params ["_officer_dogTagData", "_dogTag_taskID", "_taskID", "_globalVariableName"];

    if (_dogTagData isEqualTo _officer_dogTagData) then {
        [_thisType, _thisId] call CBA_fnc_removeEventHandler;
        [_dogTag_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
        private _base_taskID = _taskID + "bs";
        [[_base_taskID, _taskID], 28, btc_create_object_point, [_dogTagData select 0, typeOf btc_create_object_point]] remoteExecCall ["btc_fnc_task_create", 2];
        missionNamespace setVariable [_globalVariableName, _item, 2];
    };
    _this
}, [_officer_dogTagData, _dogTag_taskID, _taskID, _globalVariableName]] remoteExecCall ["CBA_fnc_addEventHandlerArgs", [0, -2] select isDedicated, _officer];

waitUntil {sleep 5; (
    true in (
        (
            allPlayers inAreaArray [getPosWorld btc_create_object_point, 100, 100]
        ) apply {(missionNamespace getVariable [_globalVariableName, ""]) in items _x}
    ) ||
    _taskID call BIS_fnc_taskCompleted)
};

_group_officer setVariable ["no_cache", false];
{
    _x setVariable ["no_cache", false];
} forEach _group;

if (_taskID call BIS_fnc_taskState isEqualTo "CANCELED") exitWith {
    [[], _group + [_group_officer, _trigger]] call btc_fnc_delete;
};

[[], [_trigger]] call btc_fnc_delete;

40 call btc_fnc_rep_change;

[_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
