extends RefCounted
class_name StadiumGeometryAudit
## Independent analytic check of an actual world-space chair pose.
static func check_pose(pose: Transform3D, section: Dictionary, layout: Dictionary) -> bool:
 var bank: Dictionary = {}
 for item: Dictionary in layout.banks:
  if item.name == section.bank: bank = item; break
 if bank.is_empty() or pose.basis.y.dot(Vector3.UP)<.9999: return false
 var p := Vector2(pose.origin.x,-pose.origin.z)
 var origin := Vector2(bank.origin[0],bank.origin[1])
 var d := p-origin
 var outward: Vector2
 var depth: float
 var lateral: float
 if bank.kind == "line":
  outward = Vector2(bank.normal[0],bank.normal[1])
  depth = d.dot(outward)
  lateral = d.dot(Vector2(bank.tangent[0],bank.tangent[1]))
  if absf(lateral)>float(bank.half)-.20: return false
  if absf(lateral-roundf(lateral/float(layout.aisle_pitch))*float(layout.aisle_pitch))<float(layout.aisle_half)+.21: return false
  if absf(lateral-roundf(lateral/float(layout.seat_pitch))*float(layout.seat_pitch))>.002: return false
 else:
  outward = d.normalized()
  depth = d.length()-float(layout.radius)
  lateral = atan2(d.y,d.x)
  if lateral<float(bank.angles[0])-.001: lateral += TAU
  var middle: float = (bank.angles[0]+bank.angles[1])*.5
  if absf(lateral-middle)*d.length()<float(layout.aisle_half)+.21: return false
 var row := roundi(depth/float(layout.tread)-.5)
 if row<0 or row>=int(bank.rows) or absf(depth-(row+.5)*float(layout.tread))>.002: return false
 var level := 1.05+mini(row,32)*.42+maxi(row-32,0)*.49
 if absf(pose.origin.y-level-.02)>.002: return false
 if bank.role!="home" and row>=32 and row<=35: return false
 var expected := Vector3(-outward.x,0,outward.y)
 return (-pose.basis.z).dot(expected)>.9999
