
content = r"""[gd_scene load_steps=3 format=3]

[ext_resource path="res://apps/character_creator/character_creator.gd" type="Script" id=1]

[node name="CharacterCreator" type="Control"]
script = ExtResource( 1 )
anchor_right = 1.0
anchor_bottom = 1.0

[node name="MainLayout" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Title" type="Label" parent="MainLayout"]
text = "Character Creator"
horizontal_alignment = 1

[node name="MainTab" type="TabContainer" parent="MainLayout"]
size_flags_vertical = 3
	
[node name="Creation" type="HSplitContainer" parent="MainLayout/MainTab"]
minimum_size = Vector2( 600, 300 )

[node name="LeftPane" type="VBoxContainer" parent="MainLayout/MainTab/Creation"]
size_flags_horizontal = 3

[node name="PartScroll" type="ScrollContainer" parent="MainLayout/MainTab/Creation/LeftPane"]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="PartsVBox" type="VBoxContainer" parent="MainLayout/MainTab/Creation/LeftPane/PartScroll"]
size_flags_vertical = 3
size_flags_horizontal = 3

[node name="RightPane" type="VBoxContainer" parent="MainLayout/MainTab/Creation"]
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="PreviewLabel" type="Label" parent="MainLayout/MainTab/Creation/RightPane"]
text = "Preview"

[node name="PreviewTexture" type="TextureRect" parent="MainLayout/MainTab/Creation/RightPane"]
custom_minimum_size = Vector2(96,96)
stretch_mode = 1
expand = true

[node name="NameLabel" type="Label" parent="MainLayout/MainTab/Creation/RightPane"]
text = "Name"

[node name="NameInput" type="LineEdit" parent="MainLayout/MainTab/Creation/RightPane"]
placeholder_text = "Enter character name"

[node name="CategoryLabel" type="Label" parent="MainLayout/MainTab/Creation/RightPane"]
text = "Category (optional)"

[node name="CategoryInput" type="LineEdit" parent="MainLayout/MainTab/Creation/RightPane"]
placeholder_text = "e.g., Warrior, Mage"

[node name="CreateBtn" type="Button" parent="MainLayout/MainTab/Creation/RightPane"]
text = "Create Character"

[node name="StatusLabel" type="Label" parent="MainLayout/MainTab/Creation/RightPane"]
text = ""

[node name="Gallery" type="HSplitContainer" parent="MainLayout/MainTab"]
[node name="GalleryList" type="VBoxContainer" parent="MainLayout/MainTab/Gallery"]
[node name="LabelGallery" type="Label" parent="MainLayout/MainTab/Gallery/GalleryList"]
text = "Gallery"

[node name="GalleryTop" type="HBoxContainer" parent="MainLayout/MainTab/Gallery/GalleryList"]

[node name="SlotCounter" type="Label" parent="MainLayout/MainTab/Gallery/GalleryList/GalleryTop"]
text = "0 of 4 slots used"

[node name="CategorySelect" type="OptionButton" parent="MainLayout/MainTab/Gallery/GalleryList/GalleryTop"]

[node name="GalleryGrid" type="ScrollContainer" parent="MainLayout/MainTab/Gallery/GalleryList"]
anchor_right = 1.0
anchor_bottom = 1.0
[node name="GalleryVBox" type="GridContainer" parent="MainLayout/MainTab/Gallery/GalleryList/GalleryGrid"]
columns = 4

[node name="Details" type="VBoxContainer" parent="MainLayout/MainTab/Gallery"]
anchor_right = 1.0
anchor_bottom = 1.0
[node name="DetailsLabel" type="Label" parent="MainLayout/MainTab/Gallery/Details"]
text = "Details"

[node name="DetailsPreview" type="TextureRect" parent="MainLayout/MainTab/Gallery/Details"]
custom_minimum_size = Vector2(96,96)
stretch_mode = 1

[node name="InventoryLabel" type="Label" parent="MainLayout/MainTab/Gallery/Details"]
text = "Inventory"

[node name="InventoryGrid" type="GridContainer" parent="MainLayout/MainTab/Gallery/Details"]
columns = 5
custom_constants/separation = 6


[node name="Graveyard" type="VBoxContainer" parent="MainLayout/MainTab"]
[node name="LabelGraveyard" type="Label" parent="MainLayout/MainTab/Graveyard"]
text = "Graveyard"

[node name="GraveyardTop" type="HBoxContainer" parent="MainLayout/MainTab/Graveyard"]

[node name="GraveyardClearBtn" type="Button" parent="MainLayout/MainTab/Graveyard/GraveyardTop"]
text = "Clear Graveyard"

[node name="GraveyardScroll" type="ScrollContainer" parent="MainLayout/MainTab/Graveyard"]
anchor_right = 1.0
anchor_bottom = 1.0
[node name="GraveyardVBox" type="VBoxContainer" parent="MainLayout/MainTab/Graveyard/GraveyardScroll"]
size_flags_vertical = 3
size_flags_horizontal = 3
"""

with open('apps/character_creator/character_creator.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
