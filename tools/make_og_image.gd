extends SceneTree
## Builds the website's link-preview image (Open Graph, 1200x630): the title background, darkened, with the logo on top.
## Only the title background and our own logo (see ATTRIBUTION.md). Usage (or tools/make_site_images.sh):
##   godot --headless --path . -s tools/make_og_image.gd  → server/static/og.jpg

const W := 1200
const H := 630
const LOGO_W := 820


func _init() -> void:
	var bg := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/title_bg.jpg"))
	var scale := maxf(float(W) / bg.get_width(), float(H) / bg.get_height())
	bg.resize(ceili(bg.get_width() * scale), ceili(bg.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	var out := bg.get_region(Rect2i((bg.get_width() - W) / 2, (bg.get_height() - H) / 2, W, H))
	out.convert(Image.FORMAT_RGBA8)
	var shade := Image.create(W, H, false, Image.FORMAT_RGBA8)
	shade.fill(Color(0.08, 0.05, 0.03, 0.6))
	out.blend_rect(shade, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var logo := Image.load_from_file(ProjectSettings.globalize_path("res://server/static/logo.png"))
	logo.convert(Image.FORMAT_RGBA8)
	var lh := int(round(logo.get_height() * float(LOGO_W) / logo.get_width()))
	logo.resize(LOGO_W, lh, Image.INTERPOLATE_LANCZOS)
	out.blend_rect(logo, Rect2i(0, 0, LOGO_W, lh), Vector2i((W - LOGO_W) / 2, (H - lh) / 2))
	out.convert(Image.FORMAT_RGB8)
	out.save_jpg(ProjectSettings.globalize_path("res://server/static/og.jpg"), 0.85)
	print("server/static/og.jpg %dx%d" % [W, H])
	quit()
