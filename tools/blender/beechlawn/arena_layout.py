"""Reference-led Hill Dickinson bowl parameters, metres, Blender XY/Z-up.

Pure geometry shared by the authoring tool. Runtime receives baked placement
and a descriptive manifest, never a dependency on this module or Blender.
Dimensions inferred from photography are deliberately separate from field size.
"""
import math

TREAD = .78
SEAT_PITCH = .55
AISLE_PITCH = 13.2
AISLE_HALF = .72
RADIUS = 9.0
CX, CY = 51.8, 31.5
BANKS = [
    dict(name='North', kind='line', role='away', origin=[60.8,0], normal=[1,0], tangent=[0,1], half=CY, rows=50),
    dict(name='South', kind='line', role='home', origin=[-60.8,0], normal=[-1,0], tangent=[0,-1], half=CY, rows=63),
    dict(name='East', kind='line', role='side', origin=[0,-40.5], normal=[0,-1], tangent=[1,0], half=CX, rows=63),
    dict(name='West', kind='line', role='side', origin=[0,40.5], normal=[0,1], tangent=[-1,0], half=CX, rows=63),
    dict(name='NorthEast', kind='arc', role='corner', origin=[CX,-CY], angles=[-math.pi/2,0], north=True, rows=63),
    dict(name='NorthWest', kind='arc', role='corner', origin=[CX,CY], angles=[0,math.pi/2], north=True, rows=63),
    dict(name='SouthWest', kind='arc', role='corner', origin=[-CX,CY], angles=[math.pi/2,math.pi], north=False, rows=63),
    dict(name='SouthEast', kind='arc', role='corner', origin=[-CX,-CY], angles=[math.pi,math.pi*1.5], north=False, rows=63),
]

def floor_height(row):
    return 1.05 + min(row,32)*.42 + max(0,row-32)*.49

def span(bank,row):
    if bank['kind']=='line':return -bank['half'],bank['half']
    a,b=bank['angles']
    if bank['north'] and row>=50:
        remaining=max(.035,1-(row-49)/14)
        if bank['name']=='NorthEast':b=a+(b-a)*remaining
        else:a=b-(b-a)*remaining
    return a,b

def point(bank,row,along,depth=0):
    distance=row*TREAD+depth
    if bank['kind']=='line':
        nx,ny=bank['normal'];tx,ty=bank['tangent']
        return bank['origin'][0]+nx*distance+tx*along,bank['origin'][1]+ny*distance+ty*along
    radius=RADIUS+distance
    return bank['origin'][0]+radius*math.cos(along),bank['origin'][1]+radius*math.sin(along)

def normal(bank,along):
    return bank['normal'] if bank['kind']=='line' else [math.cos(along),math.sin(along)]

def walkway(bank,row):
    # South's uninterrupted bank deliberately has no hospitality split.
    return bank['role']!='home' and 32<=row<=35

def aisle(bank,row,along):
    if bank['kind']=='line':
        return abs(math.remainder(along,AISLE_PITCH))<AISLE_HALF+.24
    # Radial gangways are fixed in angle, widening naturally toward the rear.
    middle=sum(bank['angles'])/2
    return abs(along-middle)*(RADIUS+(row+.5)*TREAD)<AISLE_HALF+.24

def portal(bank,row,along):
    return (bank['name']=='East' and row<6 and abs(along)<2.75) or (bank['kind']=='line' and bank['role']!='home' and 12<=row<=17 and abs(math.remainder(along-6.6,26.4))<1.45)

def make_layout():
    seats=[];sections=[];section_lookup={};rows=[]
    for bank in BANKS:
        for row in range(bank['rows']):
            a,b=span(bank,row)
            level=floor_height(row)
            rows.append(dict(bank=bank['name'],row=row,level=level,offset=row*TREAD,span=[a,b],walkway=walkway(bank,row)))
            if walkway(bank,row):continue
            if bank['kind']=='line':
                values=[i*SEAT_PITCH for i in range(math.ceil((a+.4)/SEAT_PITCH),math.floor((b-.4)/SEAT_PITCH)+1)]
            else:
                radius=RADIUS+(row+.5)*TREAD
                n=math.floor((b-a)*radius/SEAT_PITCH)
                values=[a+(i+.5)*(b-a)/n for i in range(n)]
            for along in values:
                if aisle(bank,row,along) or portal(bank,row,along):continue
                x,y=point(bank,row,along,TREAD*.5)
                nx,ny=normal(bank,along)
                deck=0 if row<32 or bank['role']=='home' else 1
                block=math.floor((along+bank.get('half',0))/AISLE_PITCH) if bank['kind']=='line' else min(2,int((along-bank['angles'][0])/(math.pi/6)))
                key=(bank['name'],deck,block)
                if key not in section_lookup:
                    section_lookup[key]=len(sections)
                    sections.append(dict(id=len(sections),bank=bank['name'],role=bank['role'],kind=bank['kind'],deck=deck,block=block))
                # Blender XY -> Godot XZ: (x,y,z) -> (x,z,-y).
                seats.append([round(x,4),round(level+.02,4),round(-y,4),round(math.atan2(nx,-ny),6),section_lookup[key]])
    for section in sections:
        entries=[e for e in seats if e[4]==section['id']]
        section['centre']=[round(sum(e[k] for e in entries)/len(entries),4) for k in range(3)]
        section['count']=len(entries)
    return seats,dict(version=1,reference='Hill Dickinson Stadium: photographic reconstruction with Rovers branding',
        inferred_dimensions=True,field=[105,68],tread=TREAD,seat_pitch=SEAT_PITCH,aisle_pitch=AISLE_PITCH,
        aisle_half=AISLE_HALF,radius=RADIUS,banks=BANKS,rows=rows,sections=sections)
