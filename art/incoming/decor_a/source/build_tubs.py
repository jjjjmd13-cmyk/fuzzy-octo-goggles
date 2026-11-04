"""Deep pet baths. Uses the original decor palette and exporter; no external art.
Blender 4.2: blender -b --factory-startup --python build_tubs.py
Delivery coordinates: Y up, front -Z, metres, flat interior floor Y=.92.
"""
import math,json,sys
from pathlib import Path
from math import sin,cos,pi

def rim_height(a,kind):
    front=max(0.,sin(a))
    h=1.27-.17*front**2
    if kind=='claw':h+=.022*abs(cos(a))**8
    if kind=='shell':
        rear=max(0.,-sin(a))
        h+=.23*rear**1.2-.038*rear**.5*(.5-.5*cos(16*a))
    return h

def basin(b,kind):
    # One closed vessel: underside -> outside -> rolled lip -> inside -> flat floor.
    # The high false bottom preserves the game's dog standing height on all tiers.
    n=96 if kind=='shell' else 48
    if kind=='wood':
        profile=[(.47,.39,.17),(.55,.46,.24),(.59,.50,.78),(.615,.543,'outer'),
                 (.615,.543,'lip_low'),(.601,.529,'lip_top'),(.570,.500,'lip_in'),
                 (.563,.495,'inner'),(.548,.487,.95),(.535,.480,.92)]
        outside='wood';rim='sky';inner='ice'
    elif kind=='claw':
        profile=[(.39,.30,.39),(.53,.42,.47),(.70,.50,.88),(.780,.545,'outer'),
                 (.780,.545,'lip_low'),(.766,.531,'lip_top'),(.731,.500,'lip_in'),
                 (.722,.495,'inner'),(.585,.490,.95),(.550,.480,.92)]
        outside='white';rim='white';inner='ice'
    else:
        profile=[(.36,.28,.48),(.49,.40,.56),(.64,.49,.94),(.726,.540,'outer'),
                 (.726,.540,'lip_low'),(.712,.526,'lip_top'),(.680,.493,'lip_in'),
                 (.672,.487,'inner'),(.570,.480,.95),(.540,.475,.92)]
        outside='pearl';rim='gold';inner='white'
    heights={'outer':-.045,'lip_low':-.022,'lip_top':0.,'lip_in':-.014,'inner':-.042}
    rings=[]
    for rx,rz,y in profile:
        ring=[]
        for k in range(n):
            a=2*pi*k/n;flute=1+.012*cos(16*a) if kind=='shell' else 1
            # Bottom and floor stay smooth; only upper shell contours are scalloped.
            if isinstance(y,(int,float)):flute=1
            h=rim_height(a,kind)+heights[y] if isinstance(y,str) else y
            ring.append((rx*cos(a)*flute,h,-rz*sin(a)*flute))
        rings.append(ring)
    for j in range(len(rings)-1):
        color=outside if j<3 else rim if j<6 else inner
        vs=rings[j]+rings[j+1]
        fs=[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
        b.mesh(vs,fs,color,'Tub')
    b.mesh(rings[0],[tuple(reversed(range(n)))],outside,'Tub')
    b.mesh(rings[-1],[tuple(range(n))],inner,'Tub')
    if kind=='wood':
        # Two hoops and full-height stave seams, following the deep barrel exterior.
        for y,rx,rz in [(.43,.569,.480),(.91,.599,.516)]:
            b.ring((0,y,0),rx,.012,'sky','Tub',n=48,m=4,oval=rz/rx)
        for k in range(24):
            a=2*pi*k/24
            b.tube([(.553*cos(a),.25,-.463*sin(a)),(.591*cos(a),.78,-.501*sin(a)),
                    (.616*cos(a),rim_height(a,kind)-.055,-.544*sin(a))],.003,'grain','Tub',n=4)
    elif kind=='shell':
        # Nine broad ivory ribs fan from the rear floor toward scalloped crest peaks.
        for k in range(9):
            a=pi+pi*k/8
            pts=[]
            for j in range(6):
                t=j/5
                pts.append(((.45+.216*t)*cos(a),.942+(rim_height(a,kind)-.981)*t,
                            -(.41+.076*t)*sin(a)))
            b.tube(pts,[.008+.016*j/5 for j in range(6)],'pearl','Tub',n=6)

def wooden_step(b):
    # Low plinth; the full-height wood vessel is nested into this step.
    b.box((0,.065,0),(1.44,.13,1.08),'wood','Stand',.05)
    b.box((0,.164,0),(1.30,.112,1.03),'wood','Stand',.04)
    b.box((0,.063,-.535),(1.20,.035,.012),'grain','Stand',.006)

def cat_feet(b):
    # Four isolated, visibly plump legs. No box, panel, or hidden central support.
    for x in [-.51,.51]:
        for z in [-.285,.285]:
            b.ball((x,.260,z),(.115,.140,.125),'pink','Stand',n=10,r=5)
            b.ball((x,.090,z-.015),(.174,.090,.190),'pink','Stand',n=12,r=6)
            for dx in [-.111,-.037,.037,.111]:
                b.ball((x+dx,.105,z-.145),(.052,.069,.071),'pink','Stand',n=10,r=4)
                b.ball((x+dx,.115,z-.208),(.028,.037,.009),'red','Stand',n=10,r=3)
            b.ball((x,.213,z-.122),(.072,.057,.012),'red','Stand',n=10,r=4)

def wave_stand(b):
    # Sculpted tapered water pedestal with a continuous wave silhouette at its base.
    n=36;vs=[]
    for y,rx,rz in [(0,.54,.44),(.09,.61,.48),(.24,.57,.45),(.43,.49,.39),(.53,.45,.35)]:
        for k in range(n):
            a=2*pi*k/n;vs.append((rx*cos(a),y,-rz*sin(a)))
    fs=[tuple(reversed(range(n))),tuple(4*n+k for k in range(n))]
    fs.extend((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(4) for k in range(n))
    b.mesh(vs,fs,'sky','Stand')
    for x in [-.36,0,.36]:
        points=[(x+.16*cos(pi*j/8),.13+.11*sin(pi*j/8),-.448) for j in range(9)]
        b.tube(points,.018,'ice','Stand',n=5)

def red_plug(b):
    c=(.18,.932,-.17)
    b.lathe(c,[(-.011,.027),(-.007,.036),(.007,.036),(.011,.027)],'red','Plug',n=16)
    b.ring((c[0],.941,c[2]),.014,.002,'pink','Plug',n=12,m=4)
    b.PIVOTS['Plug']=c

def make_tubs(b):
    for kind in ['wood','claw','shell']:
        b.reset()
        {'wood':wooden_step,'claw':cat_feet,'shell':wave_stand}[kind](b)
        basin(b,kind);red_plug(b)
        b.finish('tub_'+kind,4000,notes=(
            'Deep bath revision: flat interior floor Y=.92; front lip Y=1.10; side/rear Y=1.27'
            +(' (rear shell fan peaks at Y=1.50)' if kind=='shell' else '')
            +'; footprint <=1.6 x1.1m; rolled 4-6cm rim; separate Stand/Tub/red Plug.'
            +(' Four pink cat-paw legs Y=0..0.40, open space between legs; no pedestal box.' if kind=='claw' else '')))
        b.REPORT['tub_'+kind].update({'interior_floor_y':.92,'front_rim_y':1.10,
            'side_rim_y':1.27,'rear_rim_y':1.50 if kind=='shell' else 1.27,
            'interior_floor_xz_m':[1.07,.96] if kind=='wood' else [1.10,.96] if kind=='claw' else [1.08,.95],
            'rim_thickness_m':.05})

if __name__=='__main__':
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    import build_decor as b
    report=b.OUT/'validation_geometry.json'
    b.REPORT.update(json.loads(report.read_text()))
    make_tubs(b)
    report.write_text(json.dumps(b.REPORT,indent=2)+'\n')
