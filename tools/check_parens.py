from pathlib import Path
p=Path(r'c:\Users\Stephanus\Documents\420-world\apps\character_creator\gallery\character_gallery.gd')
s=p.read_text()
stack=[]
pairs={')':'(',']':'[','}':'{'}
for i,ch in enumerate(s):
    if ch in '([{': stack.append((ch,i))
    if ch in ')]}':
        if not stack:
            print('Unmatched closing',ch,'at',i)
            break
        top=stack.pop()
        if pairs[ch]!=top[0]:
            print('Mismatched',top,ch,'at',i)
            break
else:
    if stack:
        print('Unclosed at end, last open',stack[-1])
    else:
        print('All balanced')
