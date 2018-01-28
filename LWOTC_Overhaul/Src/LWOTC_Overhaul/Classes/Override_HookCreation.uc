class Override_HookCreation extends Object;

static function UpdateBlackMarket()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_BlackMarket BlackMarket;
	local XComGameState_LWListenerManager ListenerMgr;

	History = `XCOMHISTORY;
	BlackMarket = XComGameState_BlackMarket(History.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));

	if(!BlackMarket.bIsOpen && !BlackMarket.bNeedsScan)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Opening up Black Market");

		BlackMarket = XComGameState_BlackMarket(NewGameState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
		NewGameState.AddStateObject(BlackMarket);

		BlackMarket.ShowBlackMarket(NewGameState, true);

		History.AddGameStateToHistory(NewGameState);

		ListenerMgr = class'XComGameState_LWListenerManager'.static.GetListenerManager();
		if (ListenerMgr != none)
		{
			ListenerMgr.OnOverrideBlackMarketGoods(BlackMarket, BlackMarket, none, '');
		}

	}
}

static function UnlockBlackMarket(XComGameState StartState)
{
	local XComGameState_BlackMarket BlackMarket;
	local XComGameState_LWListenerManager ListenerMgr;

	foreach StartState.IterateByClassType(class'XComGameState_BlackMarket', BlackMarket)
	{
		break;
	}
	BlackMarket.ShowBlackMarket(StartState, true);

	foreach StartState.IterateByClassType(class'XComGameState_LWListenerManager', ListenerMgr)
	{
		break;
	}
	if (ListenerMgr != none)
	{
		ListenerMgr.OnOverrideBlackMarketGoods(BlackMarket, BlackMarket, StartState, '');
	}
}