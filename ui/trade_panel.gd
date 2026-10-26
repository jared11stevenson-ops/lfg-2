class_name TradePanel
extends PanelBase
## Merchant trade: BUY column (merchant stock at buy_price) and SELL column (your pack at sell_price).
## Emits trade_requested(holding_id, side:"buy"|"sell", item, qty).
signal trade_requested(holding_id: int, side: String, item: String, qty: int)
var model: Dictionary = {}
var buy_box: VBoxContainer
var sell_box: VBoxContainer
var coin_label: Label
var buy_buttons: Array[Button] = []
var sell_buttons: Array[Button] = []

func _init() -> void:
	super("MERCHANT", Vector2(900, 560))
	coin_label = UiStyle.label("COIN 0", 26, UiStyle.WARN)
	body.add_child(coin_label)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)
	buy_box = _column(cols, "BUY")
	sell_box = _column(cols, "SELL")

func _column(parent: Control, head: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	v.add_child(UiKit.heading(head, 24, UiStyle.GOOD))
	var sc: ScrollContainer = UiKit.scroll(300)
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	return inner

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(buy_box)
	UiKit.clear(sell_box)
	buy_buttons.clear()
	sell_buttons.clear()
	title_label.text = ("MERCHANT - %s" % m.get("holding_name", "")).strip_edges()
	coin_label.text = "YOUR COIN %d     MERCHANT COIN %d" % [int(m.get("coin", 0)), int(m.get("merchant_coin", 0))]
	var open: bool = bool(m.get("ok", false))
	if open:
		set_status("Prices: buy 125% of value, sell 60%.", UiStyle.TEXT)
	else:
		set_status(PanelModels.reason_text(String(m.get("reason", ""))), UiStyle.BAD)
	var hid: int = int(m.get("holding_id", -1))
	for r in m.get("buy", []):
		buy_box.add_child(_row("%s  %dc  (stock %d)" % [r["name"], int(r["price"]), int(r["stock"])], "BUY", open and bool(r["affordable"]), hid, "buy", String(r["item"]), buy_buttons))
	for r in m.get("sell", []):
		sell_box.add_child(_row("%s  %dc  (have %d)" % [r["name"], int(r["price"]), int(r["have"])], "SELL", open, hid, "sell", String(r["item"]), sell_buttons))

func _row(text: String, verb: String, enabled: bool, hid: int, side: String, item: String, sink: Array[Button]) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l: Label = UiStyle.label(text, 20, UiStyle.TEXT, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b: Button = UiKit.button(verb, UiStyle.PURPLE, Vector2(96, 56), 20)
	b.disabled = not enabled
	b.pressed.connect(func() -> void: trade_requested.emit(hid, side, item, 1))
	sink.append(b)
	h.add_child(b)
	var b5: Button = UiKit.button("x5", UiStyle.PURPLE, Vector2(70, 56), 20)
	b5.disabled = not enabled
	b5.pressed.connect(func() -> void: trade_requested.emit(hid, side, item, 5))
	h.add_child(b5)
	return h
