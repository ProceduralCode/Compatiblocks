// Compatiblocks



// MARK: Util

namespace Math {
	float ClampF(float x, float a, float b) { return x < a ? a : (x > b ? b : x); }
	float LerpF(float a, float b, float t) { return a + (b - a) * t; }
	vec3 LerpV(const vec3 &in a, const vec3 &in b, float t) { return a + (b - a) * t; }
	float LerpAngle(float a, float b, float t) {
		float d = b - a;
		while (d > Math::PI) d -= 2.0f * Math::PI;
		while (d < -Math::PI) d += 2.0f * Math::PI;
		return a + d * t;
	}
	float Smoothstep(float t) { return t*t*(3.0f - 2.0f*t); }
	vec3 GetForward(float h, float v) {
		float ch = Math::Cos(h), sh = Math::Sin(h);
		float cv = Math::Cos(v), sv = Math::Sin(v);
		return vec3(sh * cv, -sv, ch * cv);
	}
}

class AnimMgr {
	bool Active = false;
	double StartMs = 0;
	double DurMs = 250;
	void Start(double durMs) { DurMs = durMs < 1 ? 1 : durMs; StartMs = Time::Now; Active = true; }
	float T() const {
		if (!Active) { return 1; }
		double t = (Time::Now - StartMs) / DurMs;
		return t >= 1 ? 1 : float(Math::ClampF(float(t), 0, 1));
	}
}



// MARK: Camera

namespace Cam {
	AnimMgr@ CameraAnimMgr = AnimMgr();
	CamState StartCamState, EndCamState;

	class CamState {
		float HAngle = 0;
		float VAngle = 0;
		float TargetDist = 0;
		vec3 Pos = vec3();
		vec3 CamPos = vec3();

		vec2 get_LookUV() { return vec2(HAngle, VAngle); }

		CamState() {}
		CamState(float HAngle, float VAngle, float TargetDist, vec3 Pos) {
			this.HAngle = HAngle;
			this.VAngle = VAngle;
			this.TargetDist = TargetDist;
			this.Pos = Pos;
		}

		bool opEq(const CamState@ other) const {
			return this.HAngle == other.HAngle
				&& this.VAngle == other.VAngle
				&& this.TargetDist == other.TargetDist
				&& (this.Pos - other.Pos).Length() < 0.01;
		}
	}

	CamState Lerp(const CamState &in a, const CamState &in b, float t) {
		CamState o;
		t = Math::ClampF(t, 0.0f, 1.0f);
		o.HAngle = Math::LerpAngle(a.HAngle, b.HAngle, t);
		o.VAngle = Math::LerpAngle(a.VAngle, b.VAngle, t);
		o.TargetDist = Math::LerpF(a.TargetDist, b.TargetDist, t);
		o.Pos = Math::LerpV(a.Pos, b.Pos, t);
		return o;
	}

	CamState@ GetCurrentCamState() {
		auto ed = GetEditor(); if (ed is null) { return null; }
		auto cam = ed.OrbitalCameraControl;
		return CamState(
			cam.m_CurrentHAngle,
			cam.m_CurrentVAngle,
			cam.m_CameraToTargetDistance,
			cam.m_TargetedPosition
		);
	}
	void ApplyCamState(const CamState &in s) {
		auto ed = GetEditor(); if (ed is null) { return; }
		auto pmt = ed.PluginMapType;
		pmt.CameraTargetPosition = s.Pos;
		pmt.CameraHAngle = s.HAngle;
		pmt.CameraVAngle = s.VAngle;
	}
	bool AnimateCamTo(const CamState &in dst, int durMs=500) {
		auto ed = GetEditor(); if (ed is null) { return false; }
		StartCamState = GetCurrentCamState();
		EndCamState = dst;
		CameraAnimMgr.Start(durMs);
		return true;
	}
	void UpdateAnimAndCamera() {
		if (!HasEditorAndMap()) { return; }
		if (CameraAnimMgr is null || !CameraAnimMgr.Active) { return; }
		auto ed = GetEditor(); if (ed is null) { CameraAnimMgr.Active = false; return; }
		float t = Math::Smoothstep(CameraAnimMgr.T());
		CamState cur = Lerp(StartCamState, EndCamState, t);
		ApplyCamState(cur);
		if (t >= 1) { CameraAnimMgr.Active = false; }
	}
	bool IsAnimating() {
		return CameraAnimMgr !is null && CameraAnimMgr.Active;
	}
}



// MARK: Data Structures

enum PlaceableType { Block, Item }
enum PclipSlope { Flat, SlopeUp, SlopeDown, SlantLeft, SlantRight, DiagLeft, DiagRight, InvertedDiagLeft, InvertedDiagRight }
enum PclipRoadShape { Flat, RoadGrass, RoadDirt }

class Pclip {
	vec3 pos; // usually the position offset relative to item/block origin, but sometimes used for world position
	CGameCtnBlock::ECardinalDirections dir; // the direction upon leaving the item/block
	PclipSlope slope; // slope as you leave the item/block
	PclipRoadShape roadShape;
	Pclip() {}
	Pclip(const vec3 &in pos, CGameCtnBlock::ECardinalDirections dir, PclipSlope slope, PclipRoadShape roadShape) {
		this.pos = pos;
		this.dir = dir;
		this.slope = slope;
		this.roadShape = roadShape;
	}
}

class Placeable {
	string idName;
	PlaceableType type;
	Pclip@[] pclips;
	CGameCtnBlockInfo@ blockInfo; // block specific
	string itemPath; // item specific
	CGameItemModel@ itemModel; // cached item model (lazy loaded)

	string GetDisplayName() {
		if (type == PlaceableType::Block) {
			if (blockInfo is null) return "[null blockInfo]";
			return blockInfo.Name;
		} else if (type == PlaceableType::Item) {
			if (itemPath == "") return "[null itemPath]";
			auto fileName = itemPath.SubStr(itemPath.LastIndexOf("/") + 1);
			return fileName.SubStr(0, fileName.LastIndexOf(".")); // Remove extension
		}
		return "[unknown type]";
	}
	Pclip@ GetPclipByIndex(int index) {
		if (index < 0 || index >= int(pclips.Length)) { return null; }
		return pclips[index];
	}
	CGameCtnBlock::ECardinalDirections GetDirToMatchPclip(Pclip@ targetPclip, int pclipIndex) {
		auto pclip = GetPclipByIndex(pclipIndex);
		if (pclip is null || targetPclip is null) { return CGameCtnBlock::ECardinalDirections::North; }
		return CGameCtnBlock::ECardinalDirections((int(targetPclip.dir) + 2 - int(pclip.dir) + 4) % 4);
	}
	vec3 GetPosToMatchPclip(Pclip@ targetPclip, int pclipIndex) {
		auto pclip = GetPclipByIndex(pclipIndex);
		if (pclip is null || targetPclip is null) { return vec3(0,0,0); }
		return targetPclip.pos - RotatePosition(pclip.pos, GetDirToMatchPclip(targetPclip, pclipIndex));
	}
}

CGameItemModel@ LoadItemModel(Placeable@ placeable) {
	if (placeable is null || placeable.itemPath == "") return null;

	string fullPath = "Items/" + placeable.itemPath;
	auto fid = Fids::GetUser(fullPath);
	if (fid is null) {
		print("Failed to load item: " + fullPath);
		return null;
	}
	Fids::Preload(fid);
	return cast<CGameItemModel>(fid.Nod);
}

string GetPlaceableIdNameForBlock(CGameCtnBlockInfo@ blockInfo) {
	if (blockInfo is null) return "";
	return "Block:" + string(blockInfo.IdName).Replace("\\", "/");
}
string GetPlaceableIdNameForItem(CGameCtnAnchoredObject@ item) {
	if (item is null) return "";
	auto itemModel = item.ItemModel; if (itemModel is null) return "";
	return "Item:" + string(itemModel.IdName).Replace("\\", "/");
}

class PlaceableOption {
	Placeable@ placeable;
	int pclipIndex; // index into placeable.pclips
}






// MARK: Editor Helpers

CGameCtnEditorFree@ GetEditor() {
	auto app = GetApp();
	if (app is null) { return null; }
	return cast<CGameCtnEditorFree>(app.Editor);
}

bool HasEditorAndMap() {
	auto ed = GetEditor();
	return ed !is null && ed.Challenge !is null;
}
bool IsInTestMode() {
	auto ed = GetEditor(); if (ed is null) { return false; }
	auto pmt = ed.PluginMapType; if (pmt is null) { return false; }
	return pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::Test;
}

CGameCtnBlock::ECardinalDirections CombineDirections(CGameCtnBlock::ECardinalDirections a, CGameCtnBlock::ECardinalDirections b) { return CGameCtnBlock::ECardinalDirections((int(a) + int(b)) % 4); }

vec3 RotatePosition(const vec3 &in pos, CGameCtnBlock::ECardinalDirections dir) {
	switch (dir) {
		case CGameCtnBlock::ECardinalDirections::North: return pos;
		case CGameCtnBlock::ECardinalDirections::East: return vec3(-pos.z, pos.y, pos.x);
		case CGameCtnBlock::ECardinalDirections::South: return vec3(-pos.x, pos.y, -pos.z);
		case CGameCtnBlock::ECardinalDirections::West: return vec3(pos.z, pos.y, -pos.x);
	}
	return pos;
}

float DirectionToAngle(CGameCtnBlock::ECardinalDirections dir) {
	switch (dir) {
		case CGameCtnBlock::ECardinalDirections::North: return 0; // +Z
		case CGameCtnBlock::ECardinalDirections::East: return -Math::PI / 2; // -X (turn right)
		case CGameCtnBlock::ECardinalDirections::South: return Math::PI; // -Z
		case CGameCtnBlock::ECardinalDirections::West: return Math::PI / 2; // +X (turn left)
	}
	return 0;
}

CGameCtnBlock::ECardinalDirections CardinalDirTranslation(CGameEditorPluginMap::ECardinalDirections dir) {
	switch (dir) {
		case CGameEditorPluginMap::ECardinalDirections::North: return CGameCtnBlock::ECardinalDirections::North;
		case CGameEditorPluginMap::ECardinalDirections::East: return CGameCtnBlock::ECardinalDirections::East;
		case CGameEditorPluginMap::ECardinalDirections::South: return CGameCtnBlock::ECardinalDirections::South;
		case CGameEditorPluginMap::ECardinalDirections::West: return CGameCtnBlock::ECardinalDirections::West;
	}
	return CGameCtnBlock::ECardinalDirections::North;
}

void DrawPclip(Pclip@ pclip, const vec3 &in placeableOffset) {
	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_pclip");

	float arrowSize = 10.0;
	float thickness = 0.2 * arrowSize;
	float shaftWidth = 0.25 * arrowSize;
	float shaftLength = 0.6 * arrowSize;
	float headWidth = 0.6 * arrowSize;
	float headLength = 0.6 * arrowSize;
	float totalLength = shaftLength + headLength;

	// Bottom profile vertices (in XZ plane, Y=0)
	array<vec3> bottomProfile = {
		vec3(-shaftWidth, 0, 0),                 // 0: shaft back left
		vec3(shaftWidth, 0, 0),                  // 1: shaft back right
		vec3(shaftWidth, 0, shaftLength),        // 2: shaft front right
		vec3(headWidth, 0, shaftLength),         // 3: head base right
		vec3(0, 0, totalLength),                 // 4: head tip
		vec3(-headWidth, 0, shaftLength),        // 5: head base left
		vec3(-shaftWidth, 0, shaftLength)        // 6: shaft front left
	};

	// Create top profile
	array<vec3> topProfile;
	for (uint i = 0; i < bottomProfile.Length; i++) {
		topProfile.InsertLast(vec3(bottomProfile[i].x, thickness, bottomProfile[i].z));
	}

	vec3 worldPos = vec3(pclip.pos.x, pclip.pos.y + 64, pclip.pos.z) + placeableOffset;

	// Transform all vertices
	for (uint i = 0; i < bottomProfile.Length; i++) {
		bottomProfile[i] = RotateAndTranslate(bottomProfile[i], pclip.dir, pclip.slope, worldPos);
		topProfile[i] = RotateAndTranslate(topProfile[i], pclip.dir, pclip.slope, worldPos);
	}

	// Draw bottom profile outline
	drawInst.PushLineSegment(bottomProfile[0], bottomProfile[1]);
	drawInst.PushLineSegment(bottomProfile[1], bottomProfile[2]);
	drawInst.PushLineSegment(bottomProfile[2], bottomProfile[3]);
	drawInst.PushLineSegment(bottomProfile[3], bottomProfile[4]);
	drawInst.PushLineSegment(bottomProfile[4], bottomProfile[5]);
	drawInst.PushLineSegment(bottomProfile[5], bottomProfile[6]);
	drawInst.PushLineSegment(bottomProfile[6], bottomProfile[0]);

	// Draw top profile outline
	drawInst.PushLineSegment(topProfile[0], topProfile[1]);
	drawInst.PushLineSegment(topProfile[1], topProfile[2]);
	drawInst.PushLineSegment(topProfile[2], topProfile[3]);
	drawInst.PushLineSegment(topProfile[3], topProfile[4]);
	drawInst.PushLineSegment(topProfile[4], topProfile[5]);
	drawInst.PushLineSegment(topProfile[5], topProfile[6]);
	drawInst.PushLineSegment(topProfile[6], topProfile[0]);

	// Draw vertical edges connecting bottom to top
	for (uint i = 0; i < bottomProfile.Length; i++) {
		drawInst.PushLineSegment(bottomProfile[i], topProfile[i]);
	}

	// print("Drawing pclip at world pos (" + worldPos.x + ", " + worldPos.y + ", " + worldPos.z + ")");

	drawInst.RequestLineColor(GetRoadShapeColor(pclip.roadShape));
	drawInst.Draw();
}

vec3 RotateAndTranslate(const vec3 &in v, CGameCtnBlock::ECardinalDirections dir, PclipSlope slope, const vec3 &in worldPos) {
	vec3 result = v;

	// Direction rotation (yaw around Y)
	float yaw = DirectionToAngle(dir);

	// Slope rotation angles
	float pitch = 0, roll = 0;
	float slopeAngle = Math::PI / 12.0; // 15 degrees
	float diagAngle = Math::Atan(1.0 / 2.0); // ~26.565 degrees

	if (slope == PclipSlope::SlopeUp) pitch = -slopeAngle;
	else if (slope == PclipSlope::SlopeDown) pitch = slopeAngle;
	else if (slope == PclipSlope::SlantLeft) roll = slopeAngle;
	else if (slope == PclipSlope::SlantRight) roll = -slopeAngle;
	else if (slope == PclipSlope::DiagLeft) yaw += diagAngle;
	else if (slope == PclipSlope::DiagRight) yaw -= diagAngle;
	else if (slope == PclipSlope::InvertedDiagLeft) yaw -= diagAngle;
	else if (slope == PclipSlope::InvertedDiagRight) yaw += diagAngle;

	// Apply slope rotations first (in local space), then direction rotation
	result = RotateX(result, pitch);
	result = RotateZ(result, roll);
	result = RotateY(result, yaw);

	if (slope == PclipSlope::SlantLeft || slope == PclipSlope::SlantRight) { result.y += 4; }
	if (slope == PclipSlope::InvertedDiagLeft || slope == PclipSlope::InvertedDiagRight) { result.y += 6.5; }

	return result + worldPos;
}

vec3 RotateX(const vec3 &in v, float angle) {
	float c = Math::Cos(angle);
	float s = Math::Sin(angle);
	return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

vec3 RotateY(const vec3 &in v, float angle) {
	float c = Math::Cos(angle);
	float s = Math::Sin(angle);
	return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

vec3 RotateZ(const vec3 &in v, float angle) {
	float c = Math::Cos(angle);
	float s = Math::Sin(angle);
	return vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

vec3 GetRoadShapeColor(PclipRoadShape shape) {
	if (shape == PclipRoadShape::RoadGrass) return vec3(0, 1, 0); // Green
	if (shape == PclipRoadShape::RoadDirt) return vec3(0.6, 0.4, 0.2); // Brown
	return vec3(0.5, 0.5, 0.5); // Gray for flat
}

array<Pclip@> GetOpenPclips() {
	auto editor = GetEditor(); if (editor is null) return array<Pclip@>();
	auto map = editor.Challenge; if (map is null) return array<Pclip@>();

	array<Pclip@> allPclips;
	array<Pclip@> openClips;

	{ // Collect all block clips
		auto blocks = map.Blocks;
		for (uint i = 0; i < blocks.Length; i++) {
			auto block = blocks[i]; if (block is null) continue;
			string placeableIdName = GetPlaceableIdNameForBlock(block.BlockInfo); if (placeableIdName == "") continue;
			if (!g_Placeables.Exists(placeableIdName)) continue;
			Placeable@ info = cast<Placeable>(g_Placeables[placeableIdName]); if (info is null) continue;
			vec3 blockWorldPos = vec3(block.Coord.x * 32, block.Coord.y * 8, block.Coord.z * 32);

			// Add each pclip
			for (uint j = 0; j < info.pclips.Length; j++) {
				Pclip@ pclip = info.pclips[j];
				vec3 pclipWorldPos = blockWorldPos + RotatePosition(pclip.pos, block.Direction);
				CGameCtnBlock::ECardinalDirections pclipDir = CombineDirections(pclip.dir, block.Direction);
				allPclips.InsertLast(Pclip(pclipWorldPos, pclipDir, pclip.slope, pclip.roadShape));
			}
		}
	}

	{ // Collect all item clips
		auto items = map.AnchoredObjects;
		for (uint i = 0; i < items.Length; i++) {
			auto item = items[i]; if (item is null) continue;
			string placeableIdName = GetPlaceableIdNameForItem(item); if (placeableIdName == "") continue;
			if (!g_Placeables.Exists(placeableIdName)) continue;
			Placeable@ info = cast<Placeable>(g_Placeables[placeableIdName]); if (info is null) continue;
			vec3 itemWorldPos = item.AbsolutePositionInMap;

			// Get item rotation direction from yaw
			float yaw = item.Yaw;
			int dirInt = int(Math::Round(-yaw / (Math::PI / 2.0))) % 4;
			if (dirInt < 0) dirInt += 4; // Fix negative modulo
			CGameCtnBlock::ECardinalDirections itemDir = CGameCtnBlock::ECardinalDirections(dirInt);

			// Add each pclip
			for (uint j = 0; j < info.pclips.Length; j++) {
				Pclip@ pclip = info.pclips[j];
				vec3 pclipWorldPos = itemWorldPos + RotatePosition(pclip.pos, itemDir);
				CGameCtnBlock::ECardinalDirections pclipDir = CombineDirections(pclip.dir, itemDir);
				allPclips.InsertLast(Pclip(pclipWorldPos, pclipDir, pclip.slope, pclip.roadShape));
			}
		}
	}

	{ // Remove occupied clips
		for (uint i = 0; i < allPclips.Length; i++) {
			bool isOccupied = false;
			for (uint j = 0; j < allPclips.Length; j++) {
				if (i == j) continue;
				auto pos1 = allPclips[i].pos;
				auto pos2 = allPclips[j].pos;
				if (Math::Abs(pos1.x - pos2.x) < 2.0 &&
						Math::Abs(pos1.y - pos2.y) < 2.0 &&
						Math::Abs(pos1.z - pos2.z) < 2.0) {
					if (allPclips[i].dir == allPclips[j].dir) {
						print("Found duplicate pclip at (" + pos1.x + ", " + pos1.y + ", " + pos1.z + ")!");
					}
					isOccupied = true;
					break;
				}
			}
			if (!isOccupied) { openClips.InsertLast(allPclips[i]); }
		}
	}

	return openClips;
}

void ShowOpenPclips() {
	auto openClips = GetOpenPclips();
	for (uint i = 0; i < openClips.Length; i++) {
		DrawPclip(openClips[i], vec3(0,0,0));
	}
}

void HidePclips() {
	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_pclip");
	drawInst.Reset();
}

Pclip@ GetClosestOpenPclipToPosition(const vec3 &in position) {
	auto openClips = GetOpenPclips();
	Pclip@ bestClip = null;
	float bestD2 = 1000000;
	for (uint i = 0; i < openClips.Length; i++) {
		auto clip = openClips[i];
		float d2 = (clip.pos - position).LengthSquared();
		if (d2 < bestD2) { bestD2 = d2; @bestClip = clip; }
	}
	return bestClip;
}

Cam::CamState GetPclipCameraState(const Pclip &in pclip) {
	auto ed = GetEditor(); if (ed is null) { return Cam::CamState(); }
	auto cam = ed.OrbitalCameraControl; if (cam is null) { return Cam::CamState(); }
	// float rotOffset = Math::PI / 12.0;
	// float v = pclip.slope == PclipSlope::SlopeUp ? 0.5 - rotOffset : pclip.slope == PclipSlope::SlopeDown ? 0.5 + rotOffset : 0.5;
	float v = 0.5;
	float h = DirectionToAngle(pclip.dir);
	return Cam::CamState(h, v, cam.m_CameraToTargetDistance, pclip.pos + RotatePosition(vec3(0, 0, 16), pclip.dir));
}

Cam::CamState GetPclipCameraStateWithRelativeAngle(const Pclip &in pclip, float relativeHAngle, float vAngle, float distance) {
	float h = DirectionToAngle(pclip.dir) + relativeHAngle;
	return Cam::CamState(h, vAngle, distance, pclip.pos + RotatePosition(vec3(0, 0, 16), pclip.dir));
}

vec3 RotatePositionByYaw(const vec3 &in pos, float yaw) {
	float c = Math::Cos(yaw);
	float s = Math::Sin(yaw);
	return vec3(pos.x * c + pos.z * s, pos.y, -pos.x * s + pos.z * c);
}

CGameCtnBlock::ECardinalDirections YawToNearestDirection(float yaw) {
	while (yaw > Math::PI) yaw -= 2.0 * Math::PI;
	while (yaw < -Math::PI) yaw += 2.0 * Math::PI;

	if (yaw >= -Math::PI / 4 && yaw < Math::PI / 4) return CGameCtnBlock::ECardinalDirections::North;
	if (yaw >= Math::PI / 4 && yaw < 3 * Math::PI / 4) return CGameCtnBlock::ECardinalDirections::West;
	if (yaw >= 3 * Math::PI / 4 || yaw < -3 * Math::PI / 4) return CGameCtnBlock::ECardinalDirections::South;
	return CGameCtnBlock::ECardinalDirections::East;
}

Pclip@ TransformPclipToWorld(Pclip@ localPclip, const vec3 &in worldPos, float yaw) {
	if (localPclip is null) return null;
	vec3 rotatedPos = RotatePositionByYaw(localPclip.pos, yaw);
	vec3 worldPclipPos = worldPos + rotatedPos;
	float pclipYaw = DirectionToAngle(localPclip.dir) + yaw;
	CGameCtnBlock::ECardinalDirections worldDir = YawToNearestDirection(pclipYaw);
	return Pclip(worldPclipPos, worldDir, localPclip.slope, localPclip.roadShape);
}

bool PclipsMatch(Pclip@ a, Pclip@ b, float posTolerance = 1.0) {
	if (a is null || b is null) return false;
	if ((a.pos - b.pos).Length() > posTolerance) return false;
	return a.dir == b.dir && a.slope == b.slope && a.roadShape == b.roadShape;
}

bool PclipsConnect(Pclip@ a, Pclip@ b, float posTolerance = 1.0) {
	if (a is null || b is null) return false;
	if ((a.pos - b.pos).Length() > posTolerance) return false;
	int dirDiff = (int(a.dir) - int(b.dir) + 4) % 4; // Check opposite directions (differ by 2, or 180 degrees)
	if (dirDiff != 2) return false;
	if (GetMatchingSlope(a.slope) != b.slope) return false;
	if (a.roadShape != b.roadShape) return false;
	return true;
}

float GetBlockYaw(CGameCtnBlock@ block) {
	if (block is null) return 0;
	return DirectionToAngle(CardinalDirTranslation(block.Dir));
}























// MARK: Database

void LoadPlaceablesData() {
	string jsonPath = IO::FromStorageFolder("clipdata.json");
	string jsonStr = "";
	if (IO::FileExists(jsonPath)) {
		IO::File file;
		file.Open(jsonPath, IO::FileMode::Read);
		jsonStr = file.ReadToEnd();
		file.Close();
	}
	if (jsonStr == "") { jsonStr = "{\"placeables\": []}"; }
	auto data = Json::Parse(jsonStr);
	auto placeables = data["placeables"];

	print("Loading " + placeables.Length + " placeables from clipdata.json");

	// Build blockInfo dictionary
	dictionary blockInfoDict;
	auto editor = GetEditor(); if (editor is null) return;
	auto challenge = editor.Challenge; if (challenge is null) return;
	auto blocks = challenge.Blocks;
	for (uint i = 0; i < blocks.Length; i++) {
		auto block = blocks[i];
		auto blockInfo = block.BlockInfo;
		if (blockInfo !is null) {
			@blockInfoDict[blockInfo.IdName] = blockInfo;
		}
	}

	for (uint i = 0; i < placeables.Length; i++) {
		auto pData = placeables[i];

		Placeable p;
		p.idName = string(pData["idName"]).Replace("\\", "/");

		{ // Parse type prefix from idName
			if (p.idName.IndexOf(":") == -1) {
				print("  Invalid placeable idName (missing type prefix): " + p.idName);
				continue;
			}
			string typeStr = p.idName.SubStr(0, p.idName.IndexOf(":"));
			if (typeStr == "Block") {
				p.type = PlaceableType::Block;
			} else if (typeStr == "Item") {
				p.type = PlaceableType::Item;
			} else {
				print("  Unknown placeable type prefix: " + typeStr);
				continue;
			}
		}

		string otherIdPart = p.idName.SubStr(p.idName.IndexOf(":") + 1);
		if (p.type == PlaceableType::Block) {
			string blockIdName = otherIdPart;
			if (blockInfoDict.Exists(blockIdName)) {
				@p.blockInfo = cast<CGameCtnBlockInfo>(blockInfoDict[blockIdName]);
			} else {
				print("  Warning: Block info not found for idName: " + blockIdName);
				continue;
			}
		} else if (p.type == PlaceableType::Item) {
			p.itemPath = otherIdPart;
			if (!IO::FileExists(IO::FromUserGameFolder("Items/" + p.itemPath))) {
				print("  Warning: Item file not found at path: " + p.itemPath);
				continue;
			}
		}

		auto pclips = pData["pclips"];
		for (uint j = 0; j < pclips.Length; j++) {
			auto pcData = pclips[j];
			Pclip pc;

			// Parse position
			auto posData = pcData["pos"];
			pc.pos = vec3(float(posData[0]), float(posData[1]), float(posData[2]));

			// Parse direction from enum name
			string dirStr = pcData["dir"];
			if (dirStr == "North") pc.dir = CGameCtnBlock::ECardinalDirections::North;
			else if (dirStr == "East") pc.dir = CGameCtnBlock::ECardinalDirections::East;
			else if (dirStr == "South") pc.dir = CGameCtnBlock::ECardinalDirections::South;
			else if (dirStr == "West") pc.dir = CGameCtnBlock::ECardinalDirections::West;

			// Parse slope from enum name
			string slopeStr = pcData["slope"];
			if (slopeStr == "Flat") pc.slope = PclipSlope::Flat;
			else if (slopeStr == "SlopeUp") pc.slope = PclipSlope::SlopeUp;
			else if (slopeStr == "SlopeDown") pc.slope = PclipSlope::SlopeDown;
			else if (slopeStr == "SlantLeft") pc.slope = PclipSlope::SlantLeft;
			else if (slopeStr == "SlantRight") pc.slope = PclipSlope::SlantRight;
			else if (slopeStr == "DiagLeft") pc.slope = PclipSlope::DiagLeft;
			else if (slopeStr == "DiagRight") pc.slope = PclipSlope::DiagRight;
			else if (slopeStr == "InvertedDiagLeft") pc.slope = PclipSlope::InvertedDiagLeft;
			else if (slopeStr == "InvertedDiagRight") pc.slope = PclipSlope::InvertedDiagRight;

			// Parse road shape from enum name
			string shapeStr = pcData["roadShape"];
			if (shapeStr == "Flat") pc.roadShape = PclipRoadShape::Flat;
			else if (shapeStr == "RoadGrass") pc.roadShape = PclipRoadShape::RoadGrass;
			else if (shapeStr == "RoadDirt") pc.roadShape = PclipRoadShape::RoadDirt;

			p.pclips.InsertLast(pc);
		}

		@g_Placeables[p.idName] = p;
	}
}

Placeable@ ParseWTMTFilepath(const string &in filepath) {
	string filename = filepath.SubStr(filepath.LastIndexOf("/") + 1);
	array<string> parts = filename.Split("_");
	if (parts.Length < 8) {
		print("  Invalid WTMT item filename: " + filename);
		return null;
	}

	string type = parts[2];          // Tur/Chi/Str
	string startSurface = parts[3];  // BiSU/BiSD/HBLeft/HBRight/Flat/BiS
	string endSurface = parts[4];    // BiSU/BiSD/HBLeft/HBRight/Flat/BiS
	string elevation = parts[5];     // Up1-4/Down1-3/Even
	string direction = parts[6];     // Left1-5/Right1-5/Center
	string sizeStr = parts[7];       // Size[N].Item.gbx

	int size = Text::ParseInt(sizeStr.SubStr(4, 1));

	Placeable p;
	p.itemPath = filepath;
	p.idName = "Item:" + filepath;
	p.type = PlaceableType::Item;

	float verticalOffset = 0;
	if (elevation.StartsWith("Up")) {
		verticalOffset = Text::ParseInt(elevation.SubStr(2)) * 8.0;
	} else if (elevation.StartsWith("Down")) {
		verticalOffset = -Text::ParseInt(elevation.SubStr(4)) * 8.0;
	}

	// Entrance pclip
	Pclip entrance;
	entrance.pos = vec3(0, 0, 16);
	entrance.dir = CGameCtnBlock::ECardinalDirections::North;
	entrance.slope = GetSlopeFromSurface(startSurface, false, verticalOffset);
	entrance.roadShape = PclipRoadShape::RoadGrass;
	p.pclips.InsertLast(entrance);

	// Exit pclip
	Pclip exit;
	exit.slope = GetSlopeFromSurface(endSurface, true, verticalOffset);
	exit.roadShape = PclipRoadShape::RoadGrass;

	if (type == "Str") {
		exit.pos = vec3(0, verticalOffset, -(size - 0.5) * 32);
		exit.dir = CGameCtnBlock::ECardinalDirections::South;
	} else if (type == "Tur") {
		float offset = (size - 0.5) * 32;
		if (direction.StartsWith("Left")) {
			exit.pos = vec3(-offset, verticalOffset, -offset + 16);
			exit.dir = CGameCtnBlock::ECardinalDirections::East;
		} else if (direction.StartsWith("Right")) {
			exit.pos = vec3(offset, verticalOffset, -offset + 16);
			exit.dir = CGameCtnBlock::ECardinalDirections::West;
		} else { // Center (U-turn)
			exit.pos = vec3(0, verticalOffset, -(size - 0.5) * 32);
			exit.dir = CGameCtnBlock::ECardinalDirections::South;
		}
	} else if (type == "Chi") {
		// Chicane: straight but laterally offset
		float lateralOffset = 0;
		if (direction.StartsWith("Left")) {
			lateralOffset = -Text::ParseInt(direction.SubStr(4)) * 32.0; // negative x
		} else if (direction.StartsWith("Right")) {
			lateralOffset = Text::ParseInt(direction.SubStr(5)) * 32.0; // positive x
		}
		exit.pos = vec3(lateralOffset, verticalOffset, -(size - 0.5) * 32);
		exit.dir = CGameCtnBlock::ECardinalDirections::South;
	}

	p.pclips.InsertLast(exit);
	return p;
}

PclipSlope GetSlopeFromSurface(const string &in surface, bool isExit, float verticalOffset) {
	if (surface == "BiSU") return isExit ? PclipSlope::SlopeUp : PclipSlope::SlopeDown;
	if (surface == "BiSD") return isExit ? PclipSlope::SlopeDown : PclipSlope::SlopeUp;
	if (surface == "HBLeft") return isExit ? PclipSlope::SlantRight : PclipSlope::SlantLeft;
	if (surface == "HBRight") return isExit ? PclipSlope::SlantLeft : PclipSlope::SlantRight;
	if (surface == "Flat") return PclipSlope::Flat;
	if (surface == "BiS") return verticalOffset >= 0 ? PclipSlope::SlopeUp : PclipSlope::SlopeDown; // guessing here
	return PclipSlope::Flat;
}

void AddWTMTItemsToDatabase() {
	string itemsPath = IO::FromUserGameFolder("Items/");
	int itemsAdded = ScanForWTMTPacks(itemsPath);
	if (itemsAdded > 0) {
		print("Added " + itemsAdded + " WTMT items to database");
	}
}

int ScanForWTMTPacks(const string &in basePath) {
	int itemsAdded = 0;
	array<string> folders = IO::IndexFolder(basePath, false);

	for (uint i = 0; i < folders.Length; i++) {
		string folderPath = folders[i];

		if (folderPath.Contains(".")) continue;

		while (folderPath.EndsWith("/") || folderPath.EndsWith("\\")) {
			folderPath = folderPath.SubStr(0, folderPath.Length - 1);
		}

		int lastSlash = Math::Max(folderPath.LastIndexOf("/"), folderPath.LastIndexOf("\\"));
		string folderName = folderPath.SubStr(lastSlash + 1);

		if (folderName.StartsWith("WTMT_")) {
			print("Found WTMT pack: " + folderName);
			itemsAdded += ProcessWTMTPack(folderPath, folderName);
		} else {
			itemsAdded += ScanForWTMTPacks(folderPath + "/");
		}
	}

	return itemsAdded;
}

int ProcessWTMTPack(const string &in packPath, const string &in packName) {
	int itemsAdded = 0;
	array<string> files = IO::IndexFolder(packPath + "/", true);

	for (uint j = 0; j < files.Length; j++) {
		string filepath = files[j];
		if (filepath.ToLower().EndsWith(".item.gbx")) {
			// Strip packPath to get relative path inside pack
			string relativeFromPack = filepath.SubStr(packPath.Length + 1).Replace("\\", "/");
			string relativePath = packName + "/" + relativeFromPack;
			string idName = "Item:" + relativePath;

			if (g_Placeables.Exists(idName)) {
				// print("  Item already exists in database: " + idName);
				continue;
			}

			Placeable@ p = ParseWTMTFilepath(relativePath);
			if (p !is null) {
				// print("  Added WTMT item to database: " + idName);
				@g_Placeables[idName] = p;
				itemsAdded++;
			}
		}
	}
	return itemsAdded;
}






// MARK: Placeable Options

Pclip@ g_SelectedPclip = null; // Currently selected pclip in the editor
dictionary g_Placeables; // All of the placeables available to be placed   key: Placeable.idName, value: Placeable@
array<PlaceableOption@> g_PlaceableOptions; // All of the placeables that match the currently selected pclip
int g_CurrentPlaceableOptionIndex = -1; // Currently selected placeable option in g_PlaceableOptions

PclipSlope GetMatchingSlope(PclipSlope slope) {
	switch (slope) {
		case PclipSlope::Flat: return PclipSlope::Flat;
		case PclipSlope::SlopeUp: return PclipSlope::SlopeDown;
		case PclipSlope::SlopeDown: return PclipSlope::SlopeUp;
		case PclipSlope::SlantLeft: return PclipSlope::SlantRight;
		case PclipSlope::SlantRight: return PclipSlope::SlantLeft;
		case PclipSlope::DiagLeft: return PclipSlope::DiagLeft;
		case PclipSlope::DiagRight: return PclipSlope::DiagRight;
		case PclipSlope::InvertedDiagLeft: return PclipSlope::InvertedDiagLeft;
		case PclipSlope::InvertedDiagRight: return PclipSlope::InvertedDiagRight;
	}
	return PclipSlope::Flat;
}

void SelectPclip(Pclip@ pclip, bool preserveRelativeAngle = false, float relativeHAngle = 0) {
	@g_SelectedPclip = pclip;
	if (g_SelectedPclip is null) return;

	auto currentCam = Cam::GetCurrentCamState();
	Cam::CamState dst;

	if (preserveRelativeAngle) {
		dst = GetPclipCameraStateWithRelativeAngle(g_SelectedPclip, relativeHAngle, currentCam.VAngle, currentCam.TargetDist);
	} else {
		dst = GetPclipCameraState(g_SelectedPclip);
	}

	Cam::AnimateCamTo(dst);
	FindCompatiblePlaceables();
	UpdatePlaceablePreview();
}

void FindCompatiblePlaceables() {
	g_PlaceableOptions.RemoveRange(0, g_PlaceableOptions.Length);
	g_CurrentPlaceableOptionIndex = -1;

	if (g_SelectedPclip is null) return;

	auto keys = g_Placeables.GetKeys();
	for (uint i = 0; i < keys.Length; i++) {
		Placeable@ placeable;
		g_Placeables.Get(keys[i], @placeable);
		if (placeable is null) continue;

		for (uint j = 0; j < placeable.pclips.Length; j++) {
			auto pclip = placeable.pclips[j];
			if (pclip.slope == GetMatchingSlope(g_SelectedPclip.slope) && pclip.roadShape == g_SelectedPclip.roadShape) {
				PlaceableOption@ opt = PlaceableOption();
				@opt.placeable = placeable;
				opt.pclipIndex = j;
				g_PlaceableOptions.InsertLast(opt);
			}
		}
	}
	print("Found " + g_PlaceableOptions.Length + " compatible placeables for selected pclip");
}

void CyclePlaceableOption(bool reverse = false) {
	if (g_PlaceableOptions.Length == 0) return;

	if (reverse) {
		g_CurrentPlaceableOptionIndex--;
		if (g_CurrentPlaceableOptionIndex < 0) {
			g_CurrentPlaceableOptionIndex = g_PlaceableOptions.Length - 1;
		}
	} else {
		g_CurrentPlaceableOptionIndex++;
		if (g_CurrentPlaceableOptionIndex >= int(g_PlaceableOptions.Length)) {
			g_CurrentPlaceableOptionIndex = 0;
		}
	}
	print("Selected placeable option: " + g_PlaceableOptions[g_CurrentPlaceableOptionIndex].placeable.GetDisplayName());
}

vec3 ScreenToWorldRay(vec2 mousePos, vec3 &out rayOrigin) {
	auto ed = GetEditor();
	if (ed is null) return vec3(0,0,1);

	vec2 screen = vec2(Draw::GetWidth(), Draw::GetHeight());
	if (screen.x == 0 || screen.y == 0) return vec3(0,0,1);

	vec2 uv = mousePos / (screen - 1.0) * 2.0 - 1.0;
	uv.x = -uv.x;

	auto cam = ed.OrbitalCameraControl;
	rayOrigin = cam.Pos;
	rayOrigin.y += 64;

	float h = cam.m_CurrentHAngle;
	float v = cam.m_CurrentVAngle;

	vec3 forward = Math::GetForward(h, v);
	vec3 right = vec3(Math::Cos(h), 0, -Math::Sin(h));
	vec3 up = Math::Cross(right, forward).Normalized();

	float fovRad = cam.m_ParamFov * (Math::PI / 180.0);
	float tanHalfFov = Math::Tan(fovRad / 2.0);
	float aspect = screen.x / screen.y;

	vec3 rayDir = forward + right * uv.x * tanHalfFov * aspect + up * uv.y * tanHalfFov;
	return rayDir.Normalized();
}

void DrawMouseRay() {
	vec2 mousePos = UI::GetMousePos();
	vec3 rayOrigin;
	vec3 rayDir = ScreenToWorldRay(mousePos, rayOrigin);

	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_ray");

	float rayLength = 1000.0; // How far to draw the ray
	vec3 rayEnd = rayOrigin + rayDir * rayLength;

	print("Ray from " + rayOrigin.x + ", " + rayOrigin.y + ", " + rayOrigin.z +
		  " to " + rayEnd.x + ", " + rayEnd.y + ", " + rayEnd.z);
	drawInst.PushLineSegment(rayOrigin, rayEnd);
	drawInst.Draw();
}

void ClearMouseRay() {
	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_ray");
	drawInst.Deregister();
}

float PointToRayDistance(vec3 point, vec3 rayOrigin, vec3 rayDir) {
	vec3 w = point - rayOrigin;
	float c1 = Math::Dot(w, rayDir);
	float c2 = Math::Dot(rayDir, rayDir);
	if (c2 < 0.0001) return 999999.0; // rayDir is zero or near-zero
	float b = c1 / c2;
	vec3 closestPoint = rayOrigin + rayDir * b;
	return (point - closestPoint).Length();
}

float GetPlaceableOptionDistanceToRay(Pclip@ selectedPclip, PlaceableOption@ opt, vec3 rayOrigin, vec3 rayDir) {
	// Find closest pclip that's not the matched one
	float closestDist = 999999.0;
	if (selectedPclip is null || opt is null || opt.placeable is null) { return closestDist; }

	// Calculate placeable world position
	vec3 placeableOrigin = opt.placeable.GetPosToMatchPclip(selectedPclip, opt.pclipIndex);
	CGameCtnBlock::ECardinalDirections combinedDir = opt.placeable.GetDirToMatchPclip(selectedPclip, opt.pclipIndex);

	for (uint i = 0; i < opt.placeable.pclips.Length; i++) {
		if (int(i) == opt.pclipIndex) continue;
		auto pclip = opt.placeable.pclips[i];
		vec3 pclipWorldPos = placeableOrigin + RotatePosition(pclip.pos, combinedDir);
		pclipWorldPos.y += 64;
		float dist = PointToRayDistance(pclipWorldPos, rayOrigin, rayDir);
		if (dist < closestDist) { closestDist = dist; }
	}
	return closestDist;
}

int GetClosestPlaceableOptionToMouseRay() {
	vec2 mousePos = UI::GetMousePos();
	vec3 rayOrigin;
	vec3 rayDir = ScreenToWorldRay(mousePos, rayOrigin);

	int closestIndex = -1;
	float closestDist = 999999.0;

	for (uint i = 0; i < g_PlaceableOptions.Length; i++) {
		// Deterministic 3D offset based on index
		float offsetScale = 2.0; // Adjust this to control spread
		vec3 offset(
			Math::Sin(i * 12.9898) * offsetScale,
			Math::Sin(i * 78.233) * offsetScale,
			Math::Sin(i * 45.164) * offsetScale
		);

		float dist = GetPlaceableOptionDistanceToRay(g_SelectedPclip, g_PlaceableOptions[i], rayOrigin + offset, rayDir);
		if (dist < closestDist) {
			closestDist = dist;
			closestIndex = i;
		}
	}

	return closestIndex;
}

void SortPlaceableOptionsToPutOnesCloseToMouseRayFirst(int closeCount) {
	vec2 mousePos = UI::GetMousePos();
	vec3 rayOrigin;
	vec3 rayDir = ScreenToWorldRay(mousePos, rayOrigin);

	array<float> distances;
	for (int i = 0; i < int(g_PlaceableOptions.Length); i++) {
		distances.InsertLast(GetPlaceableOptionDistanceToRay(g_SelectedPclip, g_PlaceableOptions[i], rayOrigin, rayDir));
	}

	for (int n = 0; n < closeCount; n++) {
		int closestIndex = -1;
		float closestDist = 999999.0;
		for (int i = n; i < int(g_PlaceableOptions.Length); i++) {
			if (distances[i] < closestDist) {
				closestDist = distances[i];
				closestIndex = i;
			}
		}
		if (closestIndex != -1 && closestIndex != n) {
			auto tempOpt = g_PlaceableOptions[n];
			@g_PlaceableOptions[n] = g_PlaceableOptions[closestIndex];
			@g_PlaceableOptions[closestIndex] = tempOpt;

			float tempDist = distances[n];
			distances[n] = distances[closestIndex];
			distances[closestIndex] = tempDist;
		}
	}
}

void SortPlaceableOptionsByMouseRay() {
	vec2 mousePos = UI::GetMousePos();
	vec3 rayOrigin;
	vec3 rayDir = ScreenToWorldRay(mousePos, rayOrigin);

	array<float> distances;
	for (uint i = 0; i < g_PlaceableOptions.Length; i++) {
		distances.InsertLast(GetPlaceableOptionDistanceToRay(g_SelectedPclip, g_PlaceableOptions[i], rayOrigin, rayDir));
	}

	for (uint i = 0; i < g_PlaceableOptions.Length; i++) {
		for (uint j = i + 1; j < g_PlaceableOptions.Length; j++) {
			if (distances[j] < distances[i]) {
				auto tempOpt = g_PlaceableOptions[i];
				@g_PlaceableOptions[i] = g_PlaceableOptions[j];
				@g_PlaceableOptions[j] = tempOpt;

				float tempDist = distances[i];
				distances[i] = distances[j];
				distances[j] = tempDist;
			}
		}
	}
}






// MARK: Placement

void PlaceCurrentPlaceable() {
	print("Placing current placeable...");
	if (g_SelectedPclip is null) { print("No pclip selected"); return; }
	if (g_CurrentPlaceableOptionIndex < 0 || g_CurrentPlaceableOptionIndex >= int(g_PlaceableOptions.Length)) { print("No placeable option selected"); return; }
	auto opt = g_PlaceableOptions[g_CurrentPlaceableOptionIndex];
	if (opt is null || opt.placeable is null) { print("Invalid placeable option"); return; }

	vec3 worldPos = opt.placeable.GetPosToMatchPclip(g_SelectedPclip, opt.pclipIndex);
	CGameCtnBlock::ECardinalDirections finalDir = opt.placeable.GetDirToMatchPclip(g_SelectedPclip, opt.pclipIndex);
	vec3 rotation = vec3(0, DirectionToAngle(finalDir), 0);

	bool placed = false;
	if (opt.placeable.type == PlaceableType::Block) {
		placed = PlaceBlock(opt.placeable, worldPos, rotation);
	} else if (opt.placeable.type == PlaceableType::Item) {
		placed = PlaceItem(opt.placeable, worldPos, rotation);
	}

	if (placed) {
		// Get the current camera state before losing the selected pclip
		auto currentCam = Cam::GetCurrentCamState();
		float relativeHAngle = currentCam.HAngle - DirectionToAngle(g_SelectedPclip.dir);

		DeselectRoadExit();

		// Move to an open pclip on the newly placed placeable
		// Find another pclip on this placeable (not the one we just matched)
		for (uint i = 0; i < opt.placeable.pclips.Length; i++) {
			if (int(i) == opt.pclipIndex) continue; // Skip the pclip we just connected
			auto worldPclip = TransformPclipToWorld(opt.placeable.pclips[i], worldPos, rotation.y);
			SelectPclip(worldPclip, true, relativeHAngle);
			break; // Use the first available pclip
		}
	}
}

bool PlaceBlock(Placeable@ placeable, vec3 worldPos, vec3 rotation) {
	if (placeable.blockInfo is null) { print("Block info is null"); return false; }

	auto ed = GetEditor();
	if (ed is null) return false;

	// Use vec3 placement for off-grid positioning
	auto spec = Editor::MakeBlockSpec(placeable.blockInfo, worldPos, rotation);

	Editor::BlockSpec@[] specs = { spec };
	bool placed = Editor::PlaceBlocks(specs, true);  // true = add to undo

	if (placed) {
		print("Placed block: " + placeable.GetDisplayName());
	} else {
		print("Failed to place block");
	}
	return placed;
}

bool PlaceItem(Placeable@ placeable, vec3 worldPos, vec3 rotation) {
	auto itemModel = LoadItemModel(placeable);
	if (itemModel is null) {
		print("Failed to load item model");
		return false;
	}

	auto spec = Editor::MakeItemSpec(itemModel, worldPos, rotation);
	Editor::ItemSpec@[] specs = { spec };
	bool placed = Editor::PlaceItems(specs, true);

	if (placed) {
		print("Placed item: " + placeable.GetDisplayName());
	} else {
		print("Failed to place item");
	}
	return placed;
}

void UndoPlacement() {
	if (g_SelectedPclip is null) { print("No pclip selected for undo"); return; }

	// Capture relative angle before we lose the current pclip
	auto currentCam = Cam::GetCurrentCamState();
	float relativeHAngle = currentCam.HAngle - DirectionToAngle(g_SelectedPclip.dir);

	auto ed = GetEditor(); if (ed is null) return;
	auto map = ed.Challenge; if (map is null) return;

	Placeable@ foundPlaceable = null;
	vec3 foundWorldPos;
	float foundYaw = 0;
	CGameCtnBlock@ blockToDelete = null;
	CGameCtnAnchoredObject@ itemToDelete = null;
	int matchedPclipIndex = -1;

	{ // Check blocks
		for (uint i = 0; i < map.Blocks.Length; i++) {
			auto block = map.Blocks[i];
			string idName = GetPlaceableIdNameForBlock(block.BlockInfo);
			if (!g_Placeables.Exists(idName)) continue;

			Placeable@ placeable;
			g_Placeables.Get(idName, @placeable);
			if (placeable is null) continue;

			vec3 blockPos = vec3(block.Coord.x * 32, block.Coord.y * 8 - 64, block.Coord.z * 32);
			float blockYaw = GetBlockYaw(block);

			for (uint j = 0; j < placeable.pclips.Length; j++) {
				auto worldPclip = TransformPclipToWorld(placeable.pclips[j], blockPos, blockYaw);
				if (PclipsMatch(worldPclip, g_SelectedPclip)) {
					@foundPlaceable = placeable;
					foundWorldPos = blockPos;
					foundYaw = blockYaw;
					@blockToDelete = block;
					matchedPclipIndex = int(j);
					break;
				}
			}
			if (foundPlaceable !is null) break;
		}
	}

	{ // Check items
		if (foundPlaceable is null) {
			for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
				auto item = map.AnchoredObjects[i];
				string idName = GetPlaceableIdNameForItem(item);
				if (!g_Placeables.Exists(idName)) continue;

				Placeable@ placeable;
				g_Placeables.Get(idName, @placeable);
				if (placeable is null) continue;

				vec3 itemPos = item.AbsolutePositionInMap;
				float itemYaw = item.Yaw;

				for (uint j = 0; j < placeable.pclips.Length; j++) {
					auto worldPclip = TransformPclipToWorld(placeable.pclips[j], itemPos, itemYaw);
					if (PclipsMatch(worldPclip, g_SelectedPclip)) {
						@foundPlaceable = placeable;
						foundWorldPos = itemPos;
						foundYaw = itemYaw;
						@itemToDelete = item;
						matchedPclipIndex = int(j);
						break;
					}
				}
				if (foundPlaceable !is null) break;
			}
		}
	}

	if (foundPlaceable is null) { print("No matching block/item found to undo"); return; }

	// Delete the block/item
	if (blockToDelete !is null) {
		CGameCtnBlock@[] toDelete = { blockToDelete };
		Editor::DeleteBlocks(toDelete, true);
		print("Deleted block: " + foundPlaceable.GetDisplayName());
	} else if (itemToDelete !is null) {
		CGameCtnAnchoredObject@[] toDelete = { itemToDelete };
		Editor::DeleteItems(toDelete, true);
		print("Deleted item: " + foundPlaceable.GetDisplayName());
	}

	// Find parent pclip
	for (uint i = 0; i < foundPlaceable.pclips.Length; i++) {
		if (int(i) == matchedPclipIndex) continue;

		auto candidatePclip = TransformPclipToWorld(foundPlaceable.pclips[i], foundWorldPos, foundYaw);

		{ // Check blocks for matching parent
			for (uint j = 0; j < map.Blocks.Length; j++) {
				auto block = map.Blocks[j];
				string idName = GetPlaceableIdNameForBlock(block.BlockInfo);
				if (!g_Placeables.Exists(idName)) continue;

				Placeable@ placeable;
				g_Placeables.Get(idName, @placeable);
				if (placeable is null) continue;

				vec3 blockPos = vec3(block.Coord.x * 32, block.Coord.y * 8 - 64, block.Coord.z * 32);
				float blockYaw = GetBlockYaw(block);

				for (uint k = 0; k < placeable.pclips.Length; k++) {
					auto worldPclip = TransformPclipToWorld(placeable.pclips[k], blockPos, blockYaw);
					if (PclipsConnect(worldPclip, candidatePclip)) {
						SelectPclip(worldPclip, true, relativeHAngle);
						print("Undo: moved to parent pclip");
						return;
					}
				}
			}
		}

		{ // Check items for matching parent
			for (uint j = 0; j < map.AnchoredObjects.Length; j++) {
				auto item = map.AnchoredObjects[j];
				string idName = GetPlaceableIdNameForItem(item);
				if (!g_Placeables.Exists(idName)) continue;

				Placeable@ placeable;
				g_Placeables.Get(idName, @placeable);
				if (placeable is null) continue;

				vec3 itemPos = item.AbsolutePositionInMap;
				float itemYaw = item.Yaw;

				for (uint k = 0; k < placeable.pclips.Length; k++) {
					auto worldPclip = TransformPclipToWorld(placeable.pclips[k], itemPos, itemYaw);
					if (PclipsConnect(worldPclip, candidatePclip)) {
						SelectPclip(worldPclip, true, relativeHAngle);
						print("Undo: moved to parent pclip");
						return;
					}
				}
			}
		}
	}

	print("Undo: deleted block/item but couldn't find parent pclip");
	DeselectRoadExit();
}




// MARK: Previews

CGameCtnBlock@ g_PreviewBlock;
CGameCtnAnchoredObject@ g_PreviewItem;
vec3 g_PreviewPos;
vec3 g_PreviewRot;
bool g_ShowingPreview = false;

void UpdatePlaceablePreview() {
	HidePlaceablePreview();
	HidePclips();

	if (g_SelectedPclip is null) return;
	if (g_CurrentPlaceableOptionIndex < 0 || g_CurrentPlaceableOptionIndex >= int(g_PlaceableOptions.Length)) return;

	auto opt = g_PlaceableOptions[g_CurrentPlaceableOptionIndex];
	if (opt is null || opt.placeable is null) return;

	g_PreviewPos = opt.placeable.GetPosToMatchPclip(g_SelectedPclip, opt.pclipIndex);
	CGameCtnBlock::ECardinalDirections finalDir = opt.placeable.GetDirToMatchPclip(g_SelectedPclip, opt.pclipIndex);

	float yaw = DirectionToAngle(finalDir);
	g_PreviewRot = vec3(0, yaw, 0);

	if (opt.placeable.type == PlaceableType::Block) {
		ShowBlockPreview(opt.placeable.blockInfo);
	} else if (opt.placeable.type == PlaceableType::Item) {
		ShowItemPreview(opt.placeable);
	}
	for (uint i = 0; i < opt.placeable.pclips.Length; i++) {
		if (int(i) == opt.pclipIndex) continue;
		auto worldPclip = TransformPclipToWorld(opt.placeable.pclips[i], g_PreviewPos, g_PreviewRot.y);
		DrawPclip(worldPclip, vec3(0,0,0));
	}
}

void ShowBlockPreview(CGameCtnBlockInfo@ blockInfo) {
	if (blockInfo is null) return;

	auto ed = GetEditor();
	if (ed is null) return;
	auto map = ed.Challenge;
	uint beforeCount = map.Blocks.Length;

	auto spec = Editor::MakeBlockSpec(blockInfo, g_PreviewPos, g_PreviewRot);
	Editor::BlockSpec@[] specs = { spec };
	bool placed = Editor::PlaceBlocks(specs, false);

	if (placed && map.Blocks.Length > beforeCount) {
		@g_PreviewBlock = map.Blocks[map.Blocks.Length - 1];
		g_ShowingPreview = true;
	}
}

void ShowItemPreview(Placeable@ placeable) {
	auto itemModel = LoadItemModel(placeable);
	if (itemModel is null) {
		print("Failed to load item model for preview");
		return;
	}

	auto ed = GetEditor();
	if (ed is null) return;
	auto map = ed.Challenge;
	uint beforeCount = map.AnchoredObjects.Length;

	auto spec = Editor::MakeItemSpec(itemModel, g_PreviewPos, g_PreviewRot);
	Editor::ItemSpec@[] specs = { spec };
	bool placed = Editor::PlaceItems(specs, false);

	if (placed && map.AnchoredObjects.Length > beforeCount) {
		@g_PreviewItem = map.AnchoredObjects[map.AnchoredObjects.Length - 1];
		g_ShowingPreview = true;
	}
}

void HidePlaceablePreview() {
	if (!g_ShowingPreview) return;
	auto ed = GetEditor(); if (ed is null) return;
	auto map = ed.Challenge; if (map is null) return;

	if (g_PreviewBlock !is null) {
		for (uint i = 0; i < map.Blocks.Length; i++) {
			if (map.Blocks[i] is g_PreviewBlock) {
				CGameCtnBlock@[] toDelete = { g_PreviewBlock };
				Editor::DeleteBlocks(toDelete, false);
				break;
			}
		}
		@g_PreviewBlock = null;
	}
	if (g_PreviewItem !is null) {
		// verify item still exists
		for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
			if (map.AnchoredObjects[i] is g_PreviewItem) {
				CGameCtnAnchoredObject@[] toDelete = { g_PreviewItem };
				Editor::DeleteItems(toDelete, false);
				break;
			}
		}
		@g_PreviewItem = null;
	}
	g_ShowingPreview = false;
}



// MARK: Main

bool g_WindowOpen = true;

void ContinueFromClosestRoadExit() {
	Cam::CamState cs = Cam::GetCurrentCamState();
	@g_SelectedPclip = GetClosestOpenPclipToPosition(cs.Pos);
	if (g_SelectedPclip !is null) {
		HidePclips();
		SelectPclip(g_SelectedPclip);
	}
}
void DeselectRoadExit() {
	@g_SelectedPclip = null;
	g_CurrentPlaceableOptionIndex = -1;
	g_PlaceableOptions.RemoveRange(0, g_PlaceableOptions.Length);
	HidePlaceablePreview();
	HidePclips();
}

void RenderInterface() {
	if (!HasEditorAndMap()) { return; }
	if (IsInTestMode()) { return; }
	UI::Begin("Compatiblocks", g_WindowOpen, UI::WindowFlags::None);
	Cam::CamState cs = Cam::GetCurrentCamState();

	// Placement mode section
	if (g_SelectedPclip is null) {
		if (UI::Button("Continue from closest road exit ( g )")) { ContinueFromClosestRoadExit(); }
	} else {
		if (UI::Button("Deselect road exit ( g )")) { DeselectRoadExit(); }
		if (UI::Button("Place selected placeable ( space )")) { PlaceCurrentPlaceable(); }
	}

	string selectedPclipText = "Previewed placeable: ";
	if (g_CurrentPlaceableOptionIndex >= 0 && g_CurrentPlaceableOptionIndex < int(g_PlaceableOptions.Length)) {
		selectedPclipText += (g_CurrentPlaceableOptionIndex + 1) + " of " + g_PlaceableOptions.Length;
	}
	string selectedPclipDetails = "";
	if (g_SelectedPclip is null) {
		selectedPclipDetails = "(no road exit selected)";
	} else if (g_PlaceableOptions.Length == 0) {
		selectedPclipDetails = "(no compatible placeables found)";
	} else {
		if (g_CurrentPlaceableOptionIndex >= 0 && g_CurrentPlaceableOptionIndex < int(g_PlaceableOptions.Length)) {
			selectedPclipDetails = g_PlaceableOptions[g_CurrentPlaceableOptionIndex].placeable.GetDisplayName();
		} else {
			selectedPclipDetails = "(invalid selection)";
		}
	}
	UI::Text(selectedPclipText);
	UI::Text(selectedPclipDetails);
	if (UI::Button("Next ( f )")) {
		CyclePlaceableOption();
		UpdatePlaceablePreview();
	}
	UI::SameLine();
	if (UI::Button("Previous ( d )")) {
		CyclePlaceableOption(true);
		UpdatePlaceablePreview();
	}

	// Clip editor section
	UI::Separator();
	UI::Text("Clip Editor:");

	if (g_EditingPlaceable is null) {
		if (UI::Button("Select nearest block/item")) {
			SelectNearestPlaceableForEditing();
		}
	} else {
		UI::Text("Editing: " + g_EditingPlaceable.GetDisplayName());
		if (g_EditingError != "") {
			UI::PushStyleColor(UI::Col::Text, vec4(0.9, 0.4, 0.4, 1)); // Red color for error
			UI::TextWrapped("Error: " + g_EditingError);
			UI::PopStyleColor();
			if (UI::Button("Deselect")) { DeselectEditingPlaceable(); }
		} else {
			UI::Text("Clips: " + g_EditingPlaceable.pclips.Length);
			if (UI::Button("Deselect")) { DeselectEditingPlaceable(); }
			if (UI::Button("Add New Clip")) { AddNewClip(); }
			if (g_EditingPlaceable !is null && g_EditingPlaceable.pclips.Length > 0) {
				UI::SameLine();
				if (UI::Button("Next Clip")) { CycleEditClip(); }
				UI::SameLine();
				if (UI::Button("Prev Clip")) { CycleEditClip(true); }
				UI::SameLine();
				if (UI::Button("Delete Clip")) { DeleteCurrentClip(); }

				if (g_CurrentEditClipIndex >= 0 && g_CurrentEditClipIndex < int(g_EditingPlaceable.pclips.Length)) {
					auto clip = g_EditingPlaceable.pclips[g_CurrentEditClipIndex];
					UI::Text("Clip " + (g_CurrentEditClipIndex + 1) + " / " + g_EditingPlaceable.pclips.Length);
					UI::Text("Pos: " + clip.pos.x + ", " + clip.pos.y + ", " + clip.pos.z);

					// Position controls
					if (UI::Button("X-")) { AdjustClipPosition(0, -16); }
					UI::SameLine();
					if (UI::Button("X+")) { AdjustClipPosition(0, 16); }
					UI::SameLine();
					if (UI::Button("Y-")) { AdjustClipPosition(1, -8); }
					UI::SameLine();
					if (UI::Button("Y+")) { AdjustClipPosition(1, 8); }
					UI::SameLine();
					if (UI::Button("Z-")) { AdjustClipPosition(2, -16); }
					UI::SameLine();
					if (UI::Button("Z+")) { AdjustClipPosition(2, 16); }

					// Property controls
					if (UI::Button("Dir: " + GetDirectionName(clip.dir))) { CycleClipDirection(); }
					UI::SameLine();
					if (UI::Button("Slope: " + GetSlopeName(clip.slope))) { CycleClipSlope(); }
					UI::SameLine();
					if (UI::Button("Road: " + GetRoadShapeName(clip.roadShape))) { CycleClipRoadShape(); }
				}
			}

			if (UI::Button("Save to File")) {
				SaveClipsToFile();
			}
		}
	}

	// Debug section
	UI::Separator();
	UI::Text("Debug:");
	UI::Text("Target:   " + cs.Pos.x + ", " + cs.Pos.y + ", " + cs.Pos.z);
	UI::Text("Angles:   H=" + cs.HAngle + "  V=" + cs.VAngle);
	UI::Text("Dist:        " + cs.TargetDist);
	UI::Text("Selected Pclip:" + (g_SelectedPclip !is null ? "" : "  None"));
	if (g_SelectedPclip !is null) {
		UI::Text("  Pos: " + g_SelectedPclip.pos.x + ", " + g_SelectedPclip.pos.y + ", " + g_SelectedPclip.pos.z);
		UI::Text("  Dir: " + int(g_SelectedPclip.dir));
		UI::Text("  Slope: " + int(g_SelectedPclip.slope));
		UI::Text("  RoadShape: " + int(g_SelectedPclip.roadShape));
	}
	if (UI::Button("Show open pclips")) { ShowOpenPclips(); }
	if (UI::Button("Hide all pclips")) { HidePclips(); }

	UI::End();
}

mixin class KeyHook { void OnKeyPress(bool down, VirtualKey key) { ::OnKeyPress(down, key); } }
void OnKeyPress(bool down, VirtualKey key) {
	if (!down || !HasEditorAndMap()) { return; }

	if (key == VirtualKey::G) {
		if (g_SelectedPclip is null) {
			ContinueFromClosestRoadExit();
		} else {
			DeselectRoadExit();
		}
	}
	if (key == VirtualKey::E) {
		if (g_SelectedPclip !is null) {
			SortPlaceableOptionsToPutOnesCloseToMouseRayFirst(25);
			g_CurrentPlaceableOptionIndex = 0;
			UpdatePlaceablePreview();
		}
	}
	if (key == VirtualKey::C) {
		g_SelectWithMouse = !g_SelectWithMouse;
	}
	// if (key == VirtualKey::OemPeriod) { // '>' key
	if (key == VirtualKey::F) {
		CyclePlaceableOption();
		UpdatePlaceablePreview();
	}
	// if (key == VirtualKey::OemComma) { // '<' key
	if (key == VirtualKey::D) {
		CyclePlaceableOption(true);
		UpdatePlaceablePreview();
	}
	if (key == VirtualKey::Space) {
		if (g_SelectedPclip !is null && g_CurrentPlaceableOptionIndex >= 0 && g_CurrentPlaceableOptionIndex < int(g_PlaceableOptions.Length)) {
			PlaceCurrentPlaceable();
		}
		g_SelectWithMouse = true;
	}
	if (key == VirtualKey::V) {
		UndoPlacement();
	}
}

vec2 g_LastMousePos;
bool g_SelectWithMouse = true;

void Main() {
	LoadPlaceablesData();
	AddWTMTItemsToDatabase();

	while (true) {
		if (!HasEditorAndMap()) {
			g_PlaceableOptions.RemoveRange(0, g_PlaceableOptions.Length);
			g_CurrentPlaceableOptionIndex = -1;
			HidePlaceablePreview();
			HidePclips();
			@g_SelectedPclip = null;
		} else {
			auto ed = GetEditor();
			if (ed !is null) {
				auto pmt = ed.PluginMapType;
				if (pmt !is null) {
					// Automatically enable mix mapping (ghost blocks)
					pmt.EnableMixMapping = true;
				}
			}
			if (g_SelectWithMouse && g_SelectedPclip !is null && (UI::GetMousePos() != g_LastMousePos || Cam::IsAnimating())) {
				int closestIndex = GetClosestPlaceableOptionToMouseRay();
				if (closestIndex != -1 && closestIndex != g_CurrentPlaceableOptionIndex) {
					g_CurrentPlaceableOptionIndex = closestIndex;
					UpdatePlaceablePreview();
				}
			}

			// if (UI::IsMouseClicked(UI::MouseButton::Left)) {
			// 	if (g_SelectedPclip !is null && g_CurrentPlaceableOptionIndex >= 0 && g_CurrentPlaceableOptionIndex < int(g_PlaceableOptions.Length)) {
			// 		vec3 rayOrigin;
			// 		vec3 rayDir = ScreenToWorldRay(UI::GetMousePos(), rayOrigin);
			// 		float dist = GetPlaceableOptionDistanceToRay(g_SelectedPclip, g_PlaceableOptions[g_CurrentPlaceableOptionIndex], rayOrigin, rayDir);
			// 		if (dist < 50.0) { // If the mouse is far away, they're probably clicking on a menu
			// 			PlaceCurrentPlaceable();
			// 		}
			// 	}
			// }

			Cam::UpdateAnimAndCamera();
		}
		g_LastMousePos = UI::GetMousePos();
		yield();
	}
}











// MARK: Clip Editor

bool g_EditMode = false;
Placeable@ g_EditingPlaceable;
int g_CurrentEditClipIndex = -1;
vec3 g_EditingPlaceableWorldPos;
string g_EditingError = "";

void SelectNearestPlaceableForEditing() {
	auto ed = GetEditor(); if (ed is null) return;
	auto map = ed.Challenge; if (map is null) return;
	Cam::CamState cs = Cam::GetCurrentCamState();
	print("Selecting nearest block or item to camera position: " + cs.Pos.x + ", " + cs.Pos.y + ", " + cs.Pos.z);

	// Find nearest block or item
	float bestDist = 1000000;
	CGameCtnBlock@ nearestBlock;
	CGameCtnAnchoredObject@ nearestItem;
	vec3 targetPos;

	{ // Check blocks
		for (uint i = 0; i < map.Blocks.Length; i++) {
			auto block = map.Blocks[i];
			vec3 blockPos = vec3(block.Coord.x * 32, block.Coord.y * 8 - 64, block.Coord.z * 32);
			float dist = (blockPos - cs.Pos).Length();
			if (dist < bestDist) {
				bestDist = dist;
				@nearestBlock = block;
				@nearestItem = null;
				targetPos = blockPos;
			}
		}
	}

	{ // Check items
		for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
			auto item = map.AnchoredObjects[i];
			float dist = (item.AbsolutePositionInMap - cs.Pos).Length();
			if (dist < bestDist) {
				bestDist = dist;
				@nearestItem = item;
				@nearestBlock = null;
				targetPos = item.AbsolutePositionInMap;
			}
		}
	}

	// Load placeable data
	if (nearestBlock !is null) {
		LoadPlaceableForEditing(nearestBlock);
	} else if (nearestItem !is null) {
		LoadPlaceableForEditing(nearestItem);
	}

	// Add this camera animation block
	if (nearestBlock !is null || nearestItem !is null) {
		auto cam = ed.OrbitalCameraControl;
		if (cam !is null) {
			Cam::CamState dst = Cam::CamState(cs.HAngle, cs.VAngle, cam.m_CameraToTargetDistance, targetPos);
			Cam::AnimateCamTo(dst);
		}
	}
}

void LoadPlaceableForEditing(CGameCtnBlock@ block) {
	if (block is null) return;
	string idName = GetPlaceableIdNameForBlock(block.BlockInfo);

	@g_EditingPlaceable = Placeable();
	g_EditingPlaceable.idName = idName;
	g_EditingPlaceable.type = PlaceableType::Block;
	@g_EditingPlaceable.blockInfo = block.BlockInfo;
	g_EditingPlaceableWorldPos = vec3(block.Coord.x * 32, block.Coord.y * 8, block.Coord.z * 32);

	// Check rotation
	if (block.Direction != CGameCtnBlock::ECardinalDirections::North) {
		g_EditingError = "Cannot edit clips for rotated blocks. Place block facing North first.";
		g_CurrentEditClipIndex = -1;
		return;
	}
	g_EditingError = ""; // Clear error

	// Load existing clips if in database
	g_EditingPlaceable.pclips.RemoveRange(0, g_EditingPlaceable.pclips.Length);
	if (g_Placeables.Exists(idName)) {
		Placeable@ existing = cast<Placeable>(g_Placeables[idName]);
		for (uint i = 0; i < existing.pclips.Length; i++) {
			auto pclip = existing.pclips[i];
			g_EditingPlaceable.pclips.InsertLast(Pclip(pclip.pos, pclip.dir, pclip.slope, pclip.roadShape));
		}
	}

	g_CurrentEditClipIndex = g_EditingPlaceable.pclips.Length > 0 ? 0 : -1;
	UpdateEditingClipVisuals();
}

void LoadPlaceableForEditing(CGameCtnAnchoredObject@ item) {
	if (item is null) return;
	string idName = GetPlaceableIdNameForItem(item);

	@g_EditingPlaceable = Placeable();
	g_EditingPlaceable.idName = idName;
	g_EditingPlaceable.type = PlaceableType::Item;
	g_EditingPlaceableWorldPos = item.AbsolutePositionInMap;

	// Extract item path from idName
	if (idName.IndexOf(":") != -1) {
		g_EditingPlaceable.itemPath = idName.SubStr(idName.IndexOf(":") + 1);
	}

	// Check rotation
	if (Math::Abs(item.Yaw) > 0.01) {
		g_EditingError = "Cannot edit clips for rotated items. Place item facing North first.";
		g_CurrentEditClipIndex = -1;
		return;
	}
	g_EditingError = ""; // Clear error

	// Load existing clips if in database
	g_EditingPlaceable.pclips.RemoveRange(0, g_EditingPlaceable.pclips.Length);
	if (g_Placeables.Exists(idName)) {
		Placeable@ existing = cast<Placeable>(g_Placeables[idName]);
		for (uint i = 0; i < existing.pclips.Length; i++) {
			auto pclip = existing.pclips[i];
			g_EditingPlaceable.pclips.InsertLast(Pclip(pclip.pos, pclip.dir, pclip.slope, pclip.roadShape));
		}
	}

	g_CurrentEditClipIndex = g_EditingPlaceable.pclips.Length > 0 ? 0 : -1;
	UpdateEditingClipVisuals();
}

void AddNewClip() {
	Pclip newClip(vec3(0, 0, 0), CGameCtnBlock::ECardinalDirections::North, PclipSlope::Flat, PclipRoadShape::Flat);
	g_EditingPlaceable.pclips.InsertLast(newClip);
	g_CurrentEditClipIndex = int(g_EditingPlaceable.pclips.Length) - 1;
	UpdateEditingClipVisuals();
}

void DeleteCurrentClip() {
	if (g_CurrentEditClipIndex < 0 || g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) return;
	g_EditingPlaceable.pclips.RemoveAt(g_CurrentEditClipIndex);
	if (g_EditingPlaceable.pclips.Length > 0) {
		g_CurrentEditClipIndex = Math::Clamp(g_CurrentEditClipIndex, 0, int(g_EditingPlaceable.pclips.Length) - 1);
	} else {
		g_CurrentEditClipIndex = -1;
	}
	UpdateEditingClipVisuals();
}

void CycleEditClip(bool reverse = false) {
	if (g_EditingPlaceable.pclips.Length == 0) return;
	if (reverse) {
		g_CurrentEditClipIndex--;
		if (g_CurrentEditClipIndex < 0) g_CurrentEditClipIndex = int(g_EditingPlaceable.pclips.Length) - 1;
	} else {
		g_CurrentEditClipIndex++;
		if (g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) g_CurrentEditClipIndex = 0;
	}
	UpdateEditingClipVisuals();
}

void AdjustClipPosition(int axis, float amount) {
	if (g_CurrentEditClipIndex < 0 || g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) return;
	auto clip = g_EditingPlaceable.pclips[g_CurrentEditClipIndex];
	if (axis == 0) clip.pos.x += amount; // X
	else if (axis == 1) clip.pos.y += amount; // Y
	else if (axis == 2) clip.pos.z += amount; // Z
	UpdateEditingClipVisuals();
}

void CycleClipDirection() {
	if (g_CurrentEditClipIndex < 0 || g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) return;
	auto clip = g_EditingPlaceable.pclips[g_CurrentEditClipIndex];
	int dirInt = (int(clip.dir) + 1) % 4;
	clip.dir = CGameCtnBlock::ECardinalDirections(dirInt);
	UpdateEditingClipVisuals();
}

void CycleClipSlope() {
	if (g_CurrentEditClipIndex < 0 || g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) return;
	auto clip = g_EditingPlaceable.pclips[g_CurrentEditClipIndex];
	int slopeInt = (int(clip.slope) + 1) % 9; // 9 slope types
	clip.slope = PclipSlope(slopeInt);
	UpdateEditingClipVisuals();
}

void CycleClipRoadShape() {
	if (g_CurrentEditClipIndex < 0 || g_CurrentEditClipIndex >= int(g_EditingPlaceable.pclips.Length)) return;
	auto clip = g_EditingPlaceable.pclips[g_CurrentEditClipIndex];
	int shapeInt = (int(clip.roadShape) + 1) % 3; // 3 road shapes
	clip.roadShape = PclipRoadShape(shapeInt);
	UpdateEditingClipVisuals();
}

void UpdateEditingClipVisuals() {
	HidePclips();
	if (g_EditingPlaceable is null) return;

	// Draw all editing clips at block/item origin
	for (uint i = 0; i < g_EditingPlaceable.pclips.Length; i++) {
		auto clip = g_EditingPlaceable.pclips[i];
		DrawPclip(clip, g_EditingPlaceableWorldPos);
	}
}

void DeselectEditingPlaceable() {
	@g_EditingPlaceable = null;
	g_CurrentEditClipIndex = -1;
	g_EditingError = "";
	HidePclips();
}

string GetDirectionName(CGameCtnBlock::ECardinalDirections dir) {
	if (dir == CGameCtnBlock::ECardinalDirections::North) return "North";
	if (dir == CGameCtnBlock::ECardinalDirections::East) return "East";
	if (dir == CGameCtnBlock::ECardinalDirections::South) return "South";
	if (dir == CGameCtnBlock::ECardinalDirections::West) return "West";
	return "Unknown";
}

string GetSlopeName(PclipSlope slope) {
	if (slope == PclipSlope::Flat) return "Flat";
	if (slope == PclipSlope::SlopeUp) return "SlopeUp";
	if (slope == PclipSlope::SlopeDown) return "SlopeDown";
	if (slope == PclipSlope::SlantLeft) return "SlantLeft";
	if (slope == PclipSlope::SlantRight) return "SlantRight";
	if (slope == PclipSlope::DiagLeft) return "DiagLeft";
	if (slope == PclipSlope::DiagRight) return "DiagRight";
	if (slope == PclipSlope::InvertedDiagLeft) return "InvertedDiagLeft";
	if (slope == PclipSlope::InvertedDiagRight) return "InvertedDiagRight";
	return "Unknown";
}

string GetRoadShapeName(PclipRoadShape shape) {
	if (shape == PclipRoadShape::Flat) return "Flat";
	if (shape == PclipRoadShape::RoadGrass) return "RoadGrass";
	if (shape == PclipRoadShape::RoadDirt) return "RoadDirt";
	return "Unknown";
}

void SaveClipsToFile() {
	if (g_EditingPlaceable is null) return;

	string jsonPath = IO::FromStorageFolder("clipdata.json");
	string jsonStr = "";

	// Read existing file
	if (IO::FileExists(jsonPath)) {
		IO::File file;
		file.Open(jsonPath, IO::FileMode::Read);
		jsonStr = file.ReadToEnd();
		file.Close();
	}

	if (jsonStr == "") { jsonStr = "{\"placeables\": []}"; }
	auto data = Json::Parse(jsonStr);
	auto placeables = data["placeables"];

	// Find existing entry or create new
	int existingIndex = -1;
	for (uint i = 0; i < placeables.Length; i++) {
		if (string(placeables[i]["idName"]) == g_EditingPlaceable.idName) {
			existingIndex = int(i);
			break;
		}
	}

	// Build new placeable entry
	Json::Value newEntry = Json::Object();
	newEntry["idName"] = g_EditingPlaceable.idName;

	Json::Value pclipsArray = Json::Array();
	for (uint i = 0; i < g_EditingPlaceable.pclips.Length; i++) {
		auto clip = g_EditingPlaceable.pclips[i];
		Json::Value clipObj = Json::Object();

		Json::Value posArray = Json::Array();
		posArray.Add(clip.pos.x);
		posArray.Add(clip.pos.y);
		posArray.Add(clip.pos.z);
		clipObj["pos"] = posArray;

		clipObj["dir"] = GetDirectionName(clip.dir);
		clipObj["slope"] = GetSlopeName(clip.slope);
		clipObj["roadShape"] = GetRoadShapeName(clip.roadShape);

		pclipsArray.Add(clipObj);
	}
	newEntry["pclips"] = pclipsArray;

	// Update or add entry
	if (existingIndex >= 0) {
		placeables[existingIndex] = newEntry;
	} else {
		placeables.Add(newEntry);
	}

	data["placeables"] = placeables;

	// Write to file
	string output = Json::Write(data, true);
	IO::File outFile;
	outFile.Open(jsonPath, IO::FileMode::Write);
	outFile.Write(output);
	outFile.Close();

	print("Saved clips for: " + g_EditingPlaceable.idName);

	// Reload database to include changes
	LoadPlaceablesData();
}









