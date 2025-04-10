@tool
class_name LightTheme extends MonologueThemeGenerator

func setup() -> void:
	PRIMARY_COLOR = Color("f3eced")
	SECONDARY_COLOR = Color("ebe4d4")
	PRIMARY_TEXT_COLOR = Color("15090a")
	PRIMARY_TEXT_COLOR_02 = Color("15090a")
	PRIMARY_TEXT_COLOR_40 = Color("15090a")
	SECONDARY_TEXT_COLOR = Color("15090a")
	ACCENT_COLOR = Color("ac2a39")
	ERROR_COLOR = Color("c42e40")
	BACKGROUND_COLOR = Color("fbf4f5")
	super.setup()
