"""Create a nearest-neighbor contact sheet of native and converted worn sprites."""
from pathlib import Path
from PIL import Image, ImageDraw
from convert import read_dmi, convert_frame

root = Path('modular_vcg/modules/slim_bodies')
standard_body = read_dmi('icons/mob/human/bodyparts_greyscale.dmi')
slim_body = read_dmi(root/'icons/bodyparts.dmi')
standard_clothes = read_dmi('modular_darkpack/modules/clothes/icons/worn.dmi')
slim_clothes = read_dmi(root/'icons/compatible_worn_f.dmi')
examples = [('brujah_f', 'Brujah'), ('toreador_f', 'Toreador'), ('malkavian_f', 'Malkavian'), ('ventrue_f', 'Ventrue')]
image = Image.new('RGBA', (1050, 4*180+40), '#242933')
draw = ImageDraw.Draw(image)
draw.text((8, 8), 'Standard / Slim: native wardrobe, four directions (S N E W)', fill='white')
for row, (state, title) in enumerate(examples):
    top = 40+row*180
    draw.text((8, top), title, fill='white')
    for build, body in enumerate((standard_body, slim_body)):
        for direction in range(4):
            frame = Image.new('RGBA', (32,32))
            for part in ['head_f','chest_f','l_leg','r_leg','l_arm','r_arm','l_hand','r_hand']:
                frames = body['human_'+part][1]
                frame.alpha_composite(frames[min(direction,len(frames)-1)])
            clothes = (slim_clothes if build else standard_clothes).get(state)
            clothing_frame = clothes[1][direction] if clothes else convert_frame(standard_clothes[state][1][direction])
            frame.alpha_composite(clothing_frame)
            image.alpha_composite(frame.resize((128,128), Image.Resampling.NEAREST), (8+(build*4+direction)*130, top+20))
image.convert('RGB').save(root/'icons/preview.png')
print(root/'icons/preview.png')
