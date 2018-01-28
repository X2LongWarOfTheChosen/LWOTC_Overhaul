class Override_HookCreation extends Object;

static function UpdateBlackMarket()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_BlackMarket BlackMarket;
	local Listener_XComGameState_Manager ListenerMgr;

	History = `XCOMHISTORY;
	BlackMarket = XComGameState_BlackMarket(History.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));

	if(!BlackMarket.bIsOpen && !BlackMarket.bNeedsScan)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Opening up Black Market");

		BlackMarket = XComGameState_BlackMarket(NewGameState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
		NewGameState.AddStateObject(BlackMarket);

		BlackMarket.ShowBlackMarket(NewGameState, true);

		History.AddGameStateToHistory(NewGameState);

		ListenerMgr = class'Listener_XComGameState_Manager'.static.GetListenerManager();
		if (ListenerMgr != none)
		{
			ListenerMgr.OnOverrideBlackMarketGoods(BlackMarket, BlackMarket, none, '', none);
		}

	}
}

static function UnlockBlackMarket(XComGameState StartState)
{
	local XComGameState_BlackMarket BlackMarket;
	local Listener_XComGameState_Manager ListenerMgr;

	foreach StartState.IterateByClassType(class'XComGameState_BlackMarket', BlackMarket)
	{
		break;
	}
	BlackMarket.ShowBlackMarket(StartState, true);

	foreach StartState.IterateByClassType(class'Listener_XComGameState_Manager', ListenerMgr)
	{
		break;
	}
	if (ListenerMgr != none)
	{
		ListenerMgr.OnOverrideBlackMarketGoods(BlackMarket, BlackMarket, StartState, '', none);
	}
}