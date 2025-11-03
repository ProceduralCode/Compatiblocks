Old code































// void FindCompatiblePlaceables(CGameCtnBlock@ block) {
// 	if (block is null) return;

// 	g_CompatList.Clear();
// 	@g_CompatList.targetBlock = block;

// 	// Get exit clip info
// 	int exitDir = g_CompatList.GetSelectedExitClipDirection();
// 	if (exitDir < 0) {
// 		print("No valid exit clip direction");
// 		return;
// 	}

// 	// TODO: Get actual slope and road shape from block
// 	PclipSlope exitSlope = PclipSlope::Flat;
// 	PclipRoadShape exitShape = PclipRoadShape::RoadGrass;

// 	int oppositeDir = (exitDir + 2) % 4;

// 	print("Finding compatible placeables for exit direction " + exitDir);

// 	// Find compatible blocks
// 	auto ed = GetEditor();
// 	if (ed !is null) {
// 		auto pmt = ed.PluginMapType;
// 		for (uint i = 0; i < pmt.BlockModels.Length; i++) {
// 			auto info = pmt.BlockModels[i];
// 			if (info is null || info.VariantBaseAir is null) continue;

// 			// Check each clip in this block
// 			auto variant = info.VariantBaseAir;
// 			for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
// 				auto unit = variant.BlockUnitInfos[u];
// 				if (unit is null) continue;

// 				for (uint c = 0; c < unit.AllClips.Length; c++) {
// 					auto clip = unit.AllClips[c];
// 					if (clip is null) continue;

// 					// Check if this clip direction matches (when unrotated)
// 					int clipDir = GetClipDirectionFromBlockUnit(info, u, c);

// 					// For now, just match on direction
// 					// TODO: match slope and road shape too
// 					if (clipDir == 0 || clipDir == 2) {  // North or South facing clips
// 						auto placeable = Placeable();
// 						placeable.type = PlaceableType::Block;
// 						placeable.path = info.IdName;
// 						@placeable.blockInfo = info;
// 						placeable.size = int3(variant.Size.x, variant.Size.y, variant.Size.z);

// 						// Create Pclip from game clip
// 						auto pclip = Pclip();
// 						pclip.pos = int3(unit.Offset.x, unit.Offset.y, unit.Offset.z);
// 						pclip.dir = clipDir;
// 						pclip.slope = PclipSlope::Flat;  // TODO
// 						pclip.roadShape = PclipRoadShape::RoadGrass;  // TODO

// 						placeable.clips.InsertLast(pclip);
// 						g_CompatList.Add(placeable);
// 						break;  // Only add block once
// 					}
// 				}
// 			}
// 		}
// 	}

// 	// Find compatible items from database
// 	array<string> itemPaths = g_Placeables.GetKeys();
// 	for (uint i = 0; i < itemPaths.Length; i++) {
// 		PlaceableInfo@ info = cast<PlaceableInfo>(g_Placeables[itemPaths[i]]);

// 		for (uint j = 0; j < info.clips.Length; j++) {
// 			auto clip = info.clips[j];

// 			// Check if this clip matches
// 			if (clip.dir == oppositeDir &&
// 				clip.slope == exitSlope &&
// 				clip.roadShape == exitShape) {

// 				auto placeable = Placeable();
// 				placeable.type = PlaceableType::Item;
// 				placeable.path = info.path;

// 				// Copy all clips from database
// 				for (uint k = 0; k < info.clips.Length; k++) {
// 					placeable.clips.InsertLast(info.clips[k]);
// 				}

// 				// TODO: Load item model to get size
// 				placeable.size = int3(5, 1, 5);  // Placeholder

// 				g_CompatList.Add(placeable);
// 				print("Found matching item: " + info.path);
// 				break;  // Only add item once
// 			}
// 		}
// 	}

// 	print("Found " + g_CompatList.placeables.Length + " compatible placeables");
// }













// CGameCtnBlock@ GetClosestPclip() {
// 	auto editor = GetEditor(); if (editor is null) { return null; }
// 	auto cam = editor.OrbitalCameraControl; if (cam is null) { return null; }
// 	auto challenge = editor.Challenge; if (challenge is null) { return null; }
// 	auto blocks = challenge.Blocks; if (blocks.Length == 0) { return null; }
// 	auto items = challenge.Items;

// 	vec3 camTarget = cam.m_TargetedPosition;
// 	CGameCtnBlock@ bestBlock = null;
// 	float bestD2 = 1000000;

// 	for (uint i = 0; i < blocks.Length; i++) {
// 		auto b = cast<CGameCtnBlock>(blocks[i]);
// 		if (b is null || b.IsGround) continue;

// 		auto info = b.BlockInfo;
// 		if (info is null) continue;
// 		auto variant = info.VariantBaseAir;
// 		if (variant is null) continue;

// 		int3 blockCoord = int3(b.Coord.x, b.Coord.y, b.Coord.z);
// 		int blockDir = int(b.BlockDir);
// 		auto blockSize = variant.Size;
// 		int3 blockSizeI = int3(blockSize.x, blockSize.y, blockSize.z);

// 		// Check each clip position
// 		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
// 			auto unit = variant.BlockUnitInfos[u];
// 			if (unit is null) continue;

// 			for (uint c = 0; c < unit.AllClips.Length; c++) {
// 				int3 clipOffset = int3(unit.Offset.x, unit.Offset.y, unit.Offset.z);
// 				int3 rotatedOffset = RotateOffset(clipOffset, blockDir, blockSizeI);

// 				vec3 clipWorldPos = vec3(
// 					float((blockCoord.x + rotatedOffset.x) * 32 + 16),
// 					float((blockCoord.y + rotatedOffset.y) * 8 + 4) - 58,
// 					float((blockCoord.z + rotatedOffset.z) * 32 + 16)
// 				);

// 				float d2 = (clipWorldPos - camTarget).LengthSquared();
// 				if (d2 < bestD2) {
// 					bestD2 = d2;
// 					@bestBlock = b;
// 				}
// 			}
// 		}
// 	}

// 	return bestBlock;
// }

// int3 RotateOffset(int3 offset, int dir, int3 blockSize) {
// 	dir = (dir + 4) % 4;

// 	if (blockSize.x == 1 && blockSize.z == 1) {
// 		// Simple 1x1 block rotation
// 		switch (dir) {
// 			case 0: return offset; // North
// 			case 1: return int3(-offset.z, offset.y, offset.x); // East
// 			case 2: return int3(-offset.x, offset.y, -offset.z); // South
// 			case 3: return int3(offset.z, offset.y, -offset.x); // West
// 		}
// 		return offset;
// 	}

// 	// Complex rotation for larger blocks (around center)
// 	blockSize = blockSize - int3(1, 0, 1);
// 	switch (dir) {
// 		case 0: return offset; // North
// 		case 1: return int3(-offset.z + blockSize.z, offset.y, offset.x); // East
// 		case 2: return int3(-offset.x + blockSize.x, offset.y, -offset.z + blockSize.z); // South
// 		case 3: return int3(offset.z, offset.y, -offset.x + blockSize.x); // West
// 	}
// 	return offset;
// }

// // Get the direction a clip faces (0=North, 1=East, 2=South, 3=West, -1=Top/Bottom)
// int GetClipDirection(CGameCtnBlockInfo@ blockInfo, int globalClipIndex) {
// 	auto variant = blockInfo.VariantBaseAir;
// 	if (variant is null) return -1;

// 	int clipCount = 0;
// 	for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
// 		auto unit = variant.BlockUnitInfos[u];
// 		if (unit is null) continue;

// 		if (clipCount + int(unit.AllClips.Length) > globalClipIndex) {
// 			int localIndex = globalClipIndex - clipCount;

// 			if (localIndex < int(unit.ClipCount_North)) return 0;
// 			localIndex -= unit.ClipCount_North;
// 			if (localIndex < int(unit.ClipCount_East)) return 1;
// 			localIndex -= unit.ClipCount_East;
// 			if (localIndex < int(unit.ClipCount_South)) return 2;
// 			localIndex -= unit.ClipCount_South;
// 			if (localIndex < int(unit.ClipCount_West)) return 3;

// 			return -1; // Top/Bottom
// 		}
// 		clipCount += unit.AllClips.Length;
// 	}
// 	return -1;
// }

// int GetClipDirectionFromBlockUnit(CGameCtnBlockInfo@ info, uint unitIndex, uint clipIndex) {
// 	if (info is null || info.VariantBaseAir is null) return -1;
// 	auto variant = info.VariantBaseAir;
// 	if (unitIndex >= variant.BlockUnitInfos.Length) return -1;

// 	auto unit = variant.BlockUnitInfos[unitIndex];
// 	if (unit is null || clipIndex >= unit.AllClips.Length) return -1;

// 	// Calculate global clip index
// 	int globalIndex = 0;
// 	for (uint u = 0; u < unitIndex; u++) {
// 		auto prevUnit = variant.BlockUnitInfos[u];
// 		if (prevUnit !is null) {
// 			globalIndex += prevUnit.AllClips.Length;
// 		}
// 	}
// 	globalIndex += clipIndex;

// 	return GetClipDirection(info, globalIndex);
// }
















































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
		return vec3(sh * cv, sv, ch * cv);
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
	bool AnimateCamTo(const CamState &in dst, int durMs=250) {
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
}

class ClipWithUnit {
	CGameCtnBlockInfoClip@ clip;
	CGameCtnBlockUnitInfo@ unit;
	int unitIndex;
	int localClipIndex;
}

class CompatibleBlockList {
	CGameCtnBlockInfo@[] blocks;
	int currentIndex = -1;
	CGameCtnBlock@ targetBlock;
	int selectedExitClipIndex = 0;
	int selectedCandidateClipIndex = 0;
	int lastConnectedClipIndex = -1;

	void Clear() {
		blocks.RemoveRange(0, blocks.Length);
		currentIndex = -1;
		@targetBlock = null;
	}

	void Add(CGameCtnBlockInfo@ info) {
		blocks.InsertLast(info);
		if (currentIndex == -1) currentIndex = 0;
	}

	void Next() {
		if (blocks.Length == 0) return;
		currentIndex = (currentIndex + 1) % blocks.Length;
		ClampCandidateClipIndex();
	}

	void Prev() {
		if (blocks.Length == 0) return;
		currentIndex = (currentIndex - 1 + blocks.Length) % blocks.Length;
		ClampCandidateClipIndex();
	}

	void ClampCandidateClipIndex() {
		auto validClips = GetValidCandidateClips();
		if (validClips.Length == 0) {
			selectedCandidateClipIndex = 0;
		} else if (selectedCandidateClipIndex >= int(validClips.Length)) {
			selectedCandidateClipIndex = validClips.Length - 1;
		}
	}

	CGameCtnBlockInfo@ GetCurrent() {
		if (currentIndex < 0 || currentIndex >= int(blocks.Length)) return null;
		return blocks[currentIndex];
	}

	int3 GetNextCoord() {
		if (targetBlock is null) return int3(0);

		auto validClips = GetValidCandidateClips();
		if (validClips.Length == 0 || selectedCandidateClipIndex >= int(validClips.Length)) {
			return int3(targetBlock.Coord.x, targetBlock.Coord.y, targetBlock.Coord.z);
		}

		// Get exit and candidate clip info with their units
		auto exitClipInfo = GetSelectedExitClipWithUnit();
		auto candidateClipInfo = GetCandidateClipWithUnit(validClips[selectedCandidateClipIndex]);

		if (exitClipInfo is null || candidateClipInfo is null) {
			return int3(targetBlock.Coord.x, targetBlock.Coord.y, targetBlock.Coord.z);
		}

		// Get target block's absolute coord and direction
		int3 targetCoord = int3(targetBlock.Coord.x, targetBlock.Coord.y, targetBlock.Coord.z);
		int targetDir = int(targetBlock.BlockDir);

		// Get the exit clip's offset within its block
		int3 exitOffset = int3(exitClipInfo.unit.Offset.x, exitClipInfo.unit.Offset.y, exitClipInfo.unit.Offset.z);

		// Get target block size for rotation
		auto targetSize = targetBlock.BlockInfo.VariantBaseAir.Size;
		int3 targetSizeI = int3(targetSize.x, targetSize.y, targetSize.z);

		// Rotate exit offset according to target block's direction
		int3 rotatedExitOffset = RotateOffset(exitOffset, targetDir, targetSizeI);

		// Get the direction the exit clip faces
		int exitClipDir = GetSelectedExitClipDirection();
		if (exitClipDir < 0) return targetCoord;

		// Calculate absolute position of the exit clip
		int3 exitClipPos = targetCoord + rotatedExitOffset;

		// Move one block in the direction the exit faces (where candidate should connect)
		int3 connectionPoint = MoveInDirection(exitClipPos, exitClipDir, 1);

		// Now work backwards from connection point to find candidate block position
		auto candidateSize = GetCurrent().VariantBaseAir.Size;
		int3 candidateSizeI = int3(candidateSize.x, candidateSize.y, candidateSize.z);

		// Get candidate's rotation
		int candidateDir = int(GetNextDir());

		// Get candidate clip's offset within its block
		int3 candidateClipOffset = int3(candidateClipInfo.unit.Offset.x, candidateClipInfo.unit.Offset.y, candidateClipInfo.unit.Offset.z);

		// Rotate candidate clip offset according to candidate's rotation
		int3 rotatedCandidateOffset = RotateOffset(candidateClipOffset, candidateDir, candidateSizeI);

		// Candidate block position = connection point - rotated candidate clip offset
		int3 candidateBlockPos = connectionPoint - rotatedCandidateOffset;

		return candidateBlockPos;
	}

	CGameCtnBlock::ECardinalDirections GetNextDir() {
		if (targetBlock is null) return CGameCtnBlock::ECardinalDirections::North;

		// Get the selected candidate clip
		auto validClips = GetValidCandidateClips();
		if (validClips.Length == 0 || selectedCandidateClipIndex >= int(validClips.Length)) {
			return targetBlock.BlockDir;
		}

		int candidateClipGlobalIndex = validClips[selectedCandidateClipIndex];

		// Get exit and entry directions
		int exitDir = GetSelectedExitClipDirection();
		int entryDir = GetClipDirection(GetCurrent(), candidateClipGlobalIndex);

		if (exitDir < 0 || entryDir < 0) return targetBlock.BlockDir;

		// Entry clip should face opposite to exit clip
		// If exit is North (0), entry should be South (2)
		// Rotation = (exitDir - entryDir + 2) % 4
		int rotation = (exitDir - entryDir + 2 + 4) % 4;

		return CGameCtnBlock::ECardinalDirections(rotation);
	}

	void CycleExitClip(int direction) {
		if (targetBlock is null) return;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return;

		int totalClips = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;
			totalClips += unit.AllClips.Length;
		}

		if (totalClips == 0) return;

		int attempts = 0;
		do {
			selectedExitClipIndex = (selectedExitClipIndex + direction + totalClips) % totalClips;
			attempts++;
		} while ((!IsValidRoadExitClip(selectedExitClipIndex) || IsClipOccupied(selectedExitClipIndex))
					&& attempts < totalClips);
	}

	void NextExitClip() {
		CycleExitClip(1);
	}

	void PrevExitClip() {
		CycleExitClip(-1);
	}


	CGameCtnBlockInfoClip@ GetSelectedExitClip() {
		if (targetBlock is null) return null;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return null;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > selectedExitClipIndex) {
				return unit.AllClips[selectedExitClipIndex - clipCount];
			}
			clipCount += unit.AllClips.Length;
		}
		return null;
	}

	int GetSelectedExitClipDirection() {
		if (targetBlock is null) return -1;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return -1;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > selectedExitClipIndex) {
				int localClipIndex = selectedExitClipIndex - clipCount;

				// Get the clip's direction in the MODEL
				int modelDir = -1;
				if (localClipIndex < int(unit.ClipCount_North)) modelDir = 0; // North
				else {
					localClipIndex -= unit.ClipCount_North;
					if (localClipIndex < int(unit.ClipCount_East)) modelDir = 1; // East
					else {
						localClipIndex -= unit.ClipCount_East;
						if (localClipIndex < int(unit.ClipCount_South)) modelDir = 2; // South
						else {
							localClipIndex -= unit.ClipCount_South;
							if (localClipIndex < int(unit.ClipCount_West)) modelDir = 3; // West
							else return -1; // Top/Bottom
						}
					}
				}

				// Rotate the model direction by the target block's actual direction
				if (modelDir >= 0) {
					int blockDir = int(targetBlock.BlockDir);
					return (modelDir + blockDir) % 4;
				}
				return -1;
			}
			clipCount += unit.AllClips.Length;
		}
		return -1;
	}

	void NextCandidateClip() {
		auto validClips = GetValidCandidateClips();
		if (validClips.Length > 0) {
			selectedCandidateClipIndex = (selectedCandidateClipIndex + 1) % validClips.Length;
		}
	}

	void PrevCandidateClip() {
		auto validClips = GetValidCandidateClips();
		if (validClips.Length > 0) {
			selectedCandidateClipIndex = (selectedCandidateClipIndex - 1 + validClips.Length) % validClips.Length;
		}
	}

	// Returns array of clip indices that can connect to the selected exit
	int[] GetValidCandidateClips() {
		int[] validClips;
		auto current = GetCurrent();
		if (current is null) return validClips;

		auto exitClip = GetSelectedExitClip();
		if (exitClip is null) return validClips;

		auto variant = current.VariantBaseAir;
		if (variant is null) return validClips;

		int clipIndex = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			for (uint c = 0; c < unit.AllClips.Length; c++) {
				auto clip = unit.AllClips[c];
				if (clip !is null && DoClipsMatch(exitClip, clip)) {
					validClips.InsertLast(clipIndex);
				}
				clipIndex++;
			}
		}

		return validClips;
	}

	CGameCtnBlockInfoClip@ GetCandidateClipByIndex(int globalIndex) {
		auto current = GetCurrent();
		if (current is null) return null;

		auto variant = current.VariantBaseAir;
		if (variant is null) return null;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > globalIndex) {
				return unit.AllClips[globalIndex - clipCount];
			}
			clipCount += unit.AllClips.Length;
		}
		return null;
	}

	// Get the direction a clip faces (0=North, 1=East, 2=South, 3=West, -1=Top/Bottom)
	int GetClipDirection(CGameCtnBlockInfo@ blockInfo, int globalClipIndex) {
		auto variant = blockInfo.VariantBaseAir;
		if (variant is null) return -1;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > globalClipIndex) {
				int localIndex = globalClipIndex - clipCount;

				if (localIndex < int(unit.ClipCount_North)) return 0;
				localIndex -= unit.ClipCount_North;
				if (localIndex < int(unit.ClipCount_East)) return 1;
				localIndex -= unit.ClipCount_East;
				if (localIndex < int(unit.ClipCount_South)) return 2;
				localIndex -= unit.ClipCount_South;
				if (localIndex < int(unit.ClipCount_West)) return 3;

				return -1; // Top/Bottom
			}
			clipCount += unit.AllClips.Length;
		}
		return -1;
	}

	ClipWithUnit@ GetCandidateClipWithUnit(int globalIndex) {
		auto current = GetCurrent();
		if (current is null) return null;

		auto variant = current.VariantBaseAir;
		if (variant is null) return null;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > globalIndex) {
				auto result = ClipWithUnit();
				@result.clip = unit.AllClips[globalIndex - clipCount];
				@result.unit = unit;
				result.unitIndex = u;
				result.localClipIndex = globalIndex - clipCount;
				return result;
			}
			clipCount += unit.AllClips.Length;
		}
		return null;
	}
	ClipWithUnit@ GetSelectedExitClipWithUnit() {
		if (targetBlock is null) return null;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return null;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > selectedExitClipIndex) {
				auto result = ClipWithUnit();
				@result.clip = unit.AllClips[selectedExitClipIndex - clipCount];
				@result.unit = unit;
				result.unitIndex = u;
				result.localClipIndex = selectedExitClipIndex - clipCount;
				return result;
			}
			clipCount += unit.AllClips.Length;
		}
		return null;
	}
}

// Helper: Rotate an offset based on direction and block size
int3 RotateOffset(int3 offset, int dir, int3 blockSize) {
	dir = (dir + 4) % 4;

	if (blockSize.x == 1 && blockSize.z == 1) {
		// Simple 1x1 block rotation
		switch (dir) {
			case 0: return offset; // North
			case 1: return int3(-offset.z, offset.y, offset.x); // East
			case 2: return int3(-offset.x, offset.y, -offset.z); // South
			case 3: return int3(offset.z, offset.y, -offset.x); // West
		}
		return offset;
	}

	// Complex rotation for larger blocks (around center)
	blockSize = blockSize - int3(1, 0, 1);
	switch (dir) {
		case 0: return offset; // North
		case 1: return int3(-offset.z + blockSize.z, offset.y, offset.x); // East
		case 2: return int3(-offset.x + blockSize.x, offset.y, -offset.z + blockSize.z); // South
		case 3: return int3(offset.z, offset.y, -offset.x + blockSize.x); // West
	}
	return offset;
}

// Helper: Move a coordinate in a cardinal direction
int3 MoveInDirection(int3 coord, int dir, int distance) {
	switch (dir) {
		case 0: return coord + int3(0, 0, distance); // North
		case 1: return coord + int3(-distance, 0, 0); // East
		case 2: return coord + int3(0, 0, -distance); // South
		case 3: return coord + int3(distance, 0, 0); // West
	}
	return coord;
}

bool IsValidRoadClip(CGameCtnBlockInfoClip@ clip, int localIndex, CGameCtnBlockUnitInfo@ unit) {
	if (clip is null || unit is null) return false;

	// Check if it's in Top/Bottom buckets (skip these)
	if (localIndex >= int(unit.ClipCount_North + unit.ClipCount_East + unit.ClipCount_South + unit.ClipCount_West)) {
		return false;
	}

	// Known wall clip IDs (blacklist)
	if (clip.ClipGroupId.Value == 1073745660) return false; // Wall
	if (clip.SymmetricalClipId.Value == 1073755007) return false; // Slanted wall

	// Must have at least ONE valid connection ID
	return clip.ClipGroupId.Value != uint(-1)
		|| clip.SymmetricalClipGroupId.Value != uint(-1)
		|| clip.SymmetricalClipId.Value != uint(-1)
		|| clip.Id.Value != uint(-1);
}

bool IsValidRoadExitClip(int globalClipIndex) {
	if (compatList.targetBlock is null) return false;
	auto variant = compatList.targetBlock.BlockInfo.VariantBaseAir;
	if (variant is null) return false;

	int clipCount = 0;
	for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
		auto unit = variant.BlockUnitInfos[u];
		if (unit is null) continue;

		if (clipCount + int(unit.AllClips.Length) > globalClipIndex) {
			int localIndex = globalClipIndex - clipCount;
			auto clip = unit.AllClips[localIndex];
			return IsValidRoadClip(clip, localIndex, unit);
		}
		clipCount += unit.AllClips.Length;
	}
	return false;
}



// Info functions
void PrintBlockInfo(CGameCtnBlockInfo@ info, bool detailed = false) {
	if (info is null) {
		print("BlockInfo is null");
		return;
	}

	print("=== Block Info: " + info.IdName + " ===");
	print("Name: " + info.Name);
	print("IsRoad: " + info.IsRoad);
	print("IsPillar: " + info.IsPillar);

	auto variant = info.VariantBaseAir;
	if (variant !is null) {
		print("BlockUnitInfos count: " + variant.BlockUnitInfos.Length); // ADD THIS

		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) { // LOOP ALL UNITS
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			print("Unit " + u + " Clip counts:");
			print("  North: " + unit.ClipCount_North);
			print("  East: " + unit.ClipCount_East);
			print("  South: " + unit.ClipCount_South);
			print("  West: " + unit.ClipCount_West);
			print("  Top: " + unit.ClipCount_Top);
			print("  Bottom: " + unit.ClipCount_Bottom);
			print("  Total clips: " + unit.AllClips.Length);
		}
	}
	print("==================");
}
void PrintAllBlockClips(CGameCtnBlock@ block) {
	if (block is null) return;
	auto variant = block.BlockInfo.VariantBaseAir;
	if (variant is null) return;

	print("=== All clips for " + block.BlockInfo.IdName + " ===");
	int globalIndex = 0;
	for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
		auto unit = variant.BlockUnitInfos[u];
		if (unit is null) continue;

		print("Unit " + u + ":");
		for (uint c = 0; c < unit.AllClips.Length; c++) {
			auto clip = unit.AllClips[c];
			if (clip is null) continue;

			print("  Clip " + globalIndex + ":");
			print("    ClipGroupId: " + clip.ClipGroupId.Value);
			print("    SymClipGroupId: " + clip.SymmetricalClipGroupId.Value);
			print("    SymClipId: " + clip.SymmetricalClipId.Value);
			print("    Id: " + clip.Id.Value);
			print("    IsValidRoad: " + IsValidRoadClip(clip, c, unit));
			globalIndex++;
		}
	}
}


CompatibleBlockList compatList;

CGameCtnEditorFree@ GetEditor() {
	auto app = GetApp();
	if (app is null) { return null; }
	return cast<CGameCtnEditorFree>(app.Editor);
}

bool HasEditorAndMap() {
	auto ed = GetEditor();
	return ed !is null && ed.Challenge !is null;
}

CGameCtnBlock@ GetClosestBlock() {
	auto ed = GetEditor(); if (ed is null) { return null; }
	auto cam = ed.OrbitalCameraControl; if (cam is null) { return null; }
	auto challenge = ed.Challenge; if (challenge is null) { return null; }
	auto blocks = challenge.Blocks; if (blocks.Length == 0) { return null; }

	vec3 camTarget = cam.m_TargetedPosition;
	CGameCtnBlock@ bestBlock = null;
	float bestD2 = 1000000;

	for (uint i = 0; i < blocks.Length; i++) {
		auto b = cast<CGameCtnBlock>(blocks[i]);
		if (b is null || b.IsGround) continue;

		auto info = b.BlockInfo;
		if (info is null) continue;
		auto variant = info.VariantBaseAir;
		if (variant is null) continue;

		int3 blockCoord = int3(b.Coord.x, b.Coord.y, b.Coord.z);
		int blockDir = int(b.BlockDir);
		auto blockSize = variant.Size;
		int3 blockSizeI = int3(blockSize.x, blockSize.y, blockSize.z);

		// Check each clip position
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			for (uint c = 0; c < unit.AllClips.Length; c++) {
				int3 clipOffset = int3(unit.Offset.x, unit.Offset.y, unit.Offset.z);
				int3 rotatedOffset = RotateOffset(clipOffset, blockDir, blockSizeI);

				vec3 clipWorldPos = vec3(
					float((blockCoord.x + rotatedOffset.x) * 32 + 16),
					float((blockCoord.y + rotatedOffset.y) * 8 + 4) - 58,
					float((blockCoord.z + rotatedOffset.z) * 32 + 16)
				);

				float d2 = (clipWorldPos - camTarget).LengthSquared();
				if (d2 < bestD2) {
					bestD2 = d2;
					@bestBlock = b;
				}
			}
		}
	}

	return bestBlock;
}

Cam::CamState GetBlockContinuationCameraPosition(CGameCtnBlock@ block) {
	auto ed = GetEditor(); if (ed is null) { return Cam::CamState(); }
	auto cam = ed.OrbitalCameraControl; if (cam is null) { return Cam::CamState(); }

	// Get the selected exit clip's actual position
	auto exitClipInfo = compatList.GetSelectedExitClipWithUnit();
	vec3 blockCenter = vec3(
		float(block.Coord.x * 32 + 16),
		float(block.Coord.y * 8 + 4),
		float(block.Coord.z * 32 + 16)
	);

	// If we have clip info, offset to the clip's position
	if (exitClipInfo !is null) {
		auto targetSize = block.BlockInfo.VariantBaseAir.Size;
		int3 targetSizeI = int3(targetSize.x, targetSize.y, targetSize.z);
		int3 exitOffset = int3(exitClipInfo.unit.Offset.x, exitClipInfo.unit.Offset.y, exitClipInfo.unit.Offset.z);
		int3 rotatedOffset = RotateOffset(exitOffset, int(block.BlockDir), targetSizeI);

		blockCenter.x += rotatedOffset.x * 32;
		blockCenter.y += rotatedOffset.y * 8;
		blockCenter.z += rotatedOffset.z * 32;
	}

	int direction = compatList.GetSelectedExitClipDirection();
	float h, v = 0.3;
	switch (direction) {
		case 0: h = 0; break; // North
		case 1: h = -Math::PI / 2; break; // East
		case 2: h = Math::PI; break; // South
		case 3: h = Math::PI / 2; break; // West
		default: h = 0; break;
	}

	float dist = cam.m_CameraToTargetDistance;
	vec3 targetWorld = vec3(blockCenter.x, blockCenter.y - 58, blockCenter.z);

	return Cam::CamState(h, v, dist, targetWorld);
}

bool DoClipsMatch(CGameCtnBlockInfoClip@ exitClip, CGameCtnBlockInfoClip@ entryClip) {
	auto symGroups = nat2(exitClip.SymmetricalClipGroupId.Value, exitClip.SymmetricalClipGroupId2.Value);

	if (symGroups.x == uint(-1)) {
		auto clipGroups = nat2(exitClip.ClipGroupId.Value, exitClip.ClipGroupId2.Value);
		if (clipGroups.x != uint(-1)) {
			auto entryGroups = nat2(entryClip.ClipGroupId.Value, entryClip.ClipGroupId2.Value);
			return ClipsOverlap(clipGroups, entryGroups);
		}
		if (int(exitClip.SymmetricalClipId.Value) == -1) {
			return exitClip.Id.Value == entryClip.Id.Value;
		}
		// Check both directions
		return int(exitClip.SymmetricalClipId.Value) == int(entryClip.Id.Value)
			|| int(entryClip.SymmetricalClipId.Value) == int(exitClip.Id.Value);
	}

	auto entryGroups = nat2(entryClip.ClipGroupId.Value, entryClip.ClipGroupId2.Value);
	return ClipsOverlap(symGroups, entryGroups);
}

bool ClipsOverlap(nat2 left, nat2 right) {
	if (left.x == uint(-1) || right.x == uint(-1)) return false;
	if (left.x == right.x || left.x == right.y || left.y == right.x) return true;
	if (left.y == uint(-1) || right.y == uint(-1)) return false;
	return left.y == right.y;
}

bool IsClipOccupied(int clipIndex) {
	if (compatList.targetBlock is null) return false;

	auto ed = GetEditor(); if (ed is null) return false;

	// Get target clip info
	auto variant = compatList.targetBlock.BlockInfo.VariantBaseAir;
	if (variant is null) return false;

	int clipCount = 0;
	CGameCtnBlockInfoClip@ targetClip = null;
	CGameCtnBlockUnitInfo@ targetUnit = null;

	for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
		auto unit = variant.BlockUnitInfos[u];
		if (unit is null) continue;

		if (clipCount + int(unit.AllClips.Length) > clipIndex) {
			@targetClip = unit.AllClips[clipIndex - clipCount];
			@targetUnit = unit;
			break;
		}
		clipCount += unit.AllClips.Length;
	}

	if (targetClip is null || targetUnit is null) return false;

	int3 targetCoord = int3(compatList.targetBlock.Coord.x, compatList.targetBlock.Coord.y, compatList.targetBlock.Coord.z);
	int targetDir = int(compatList.targetBlock.BlockDir);

	int3 exitOffset = int3(targetUnit.Offset.x, targetUnit.Offset.y, targetUnit.Offset.z);
	auto targetSize = variant.Size;
	int3 targetSizeI = int3(targetSize.x, targetSize.y, targetSize.z);
	int3 rotatedExitOffset = RotateOffset(exitOffset, targetDir, targetSizeI);
	int3 targetClipPos = targetCoord + rotatedExitOffset;

	// Get the direction this clip faces
	int targetClipDir = compatList.GetClipDirection(compatList.targetBlock.BlockInfo, clipIndex);
	if (targetClipDir < 0) return false; // Top/bottom clips

	// Rotate the direction by the block's rotation
	targetClipDir = (targetClipDir + targetDir) % 4;

	// The connection point is one block away in the direction the clip faces
	int3 connectionPoint = MoveInDirection(targetClipPos, targetClipDir, 1);

	// Check all other blocks
	auto blocks = ed.Challenge.Blocks;
	for (int i = int(blocks.Length) - 1; i >= 0; i--) {
		auto otherBlock = cast<CGameCtnBlock>(blocks[i]);
		if (otherBlock is null) continue;
		if (otherBlock is compatList.targetBlock) continue;

		auto otherInfo = otherBlock.BlockInfo;
		if (otherInfo is null) continue;
		auto otherVariant = otherInfo.VariantBaseAir;
		if (otherVariant is null) continue;

		int3 otherCoord = int3(otherBlock.Coord.x, otherBlock.Coord.y, otherBlock.Coord.z);
		int otherDir = int(otherBlock.BlockDir);
		auto otherSize = otherVariant.Size;
		int3 otherSizeI = int3(otherSize.x, otherSize.y, otherSize.z);

		for (uint u = 0; u < otherVariant.BlockUnitInfos.Length; u++) {
			auto unit = otherVariant.BlockUnitInfos[u];
			if (unit is null) continue;

			for (uint c = 0; c < unit.AllClips.Length; c++) {
				auto otherClip = unit.AllClips[c];
				if (otherClip is null) continue;

				int3 otherClipOffset = int3(unit.Offset.x, unit.Offset.y, unit.Offset.z);
				int3 rotatedOtherOffset = RotateOffset(otherClipOffset, otherDir, otherSizeI);
				int3 otherClipPos = otherCoord + rotatedOtherOffset;

				// Check if this other clip is at the connection point
				if (connectionPoint.x == otherClipPos.x &&
				    connectionPoint.y == otherClipPos.y &&
				    connectionPoint.z == otherClipPos.z) {
					if (DoClipsMatch(targetClip, otherClip)) {
						return true;
					}
				}
			}
		}
	}

	return false;
}

void FindCompatibleBlocks(CGameCtnBlock@ targetBlock) {
	compatList.Clear();
	@compatList.targetBlock = targetBlock;

	auto ed = GetEditor(); if (ed is null) return;
	auto pmt = ed.PluginMapType;

	// Get the selected exit clip
	auto targetExitClip = compatList.GetSelectedExitClip();
	if (targetExitClip is null) {
		print("No exit clip selected");
		return;
	}
	print("Target exit clip IDs:");
	print("  SymmetricalClipId: " + targetExitClip.SymmetricalClipId.Value);
	print("  Id: " + targetExitClip.Id.Value);

	print("Finding blocks compatible with exit clip: ClipGroupId=" + targetExitClip.ClipGroupId.Value);

	for (uint i = 0; i < pmt.BlockModels.Length; i++) {
		auto candidateInfo = pmt.BlockModels[i];
		auto candidateVariant = candidateInfo.VariantBaseAir;
		if (candidateVariant is null) continue;
		if (candidateVariant.BlockUnitInfos.Length == 0) continue;

		// Check if ANY clip from candidate matches the selected exit clip
		bool found = false;
		for (uint cu = 0; cu < candidateVariant.BlockUnitInfos.Length && !found; cu++) {
			auto candidateUnit = candidateVariant.BlockUnitInfos[cu];
			if (candidateUnit is null || candidateUnit.AllClips.Length == 0) continue;

			for (uint ce = 0; ce < candidateUnit.AllClips.Length; ce++) {
				auto candidateClip = candidateUnit.AllClips[ce];
				if (candidateClip is null) continue;

				if (DoClipsMatch(targetExitClip, candidateClip)) {
					compatList.Add(candidateInfo);
					found = true;
					break;
				}
			}
		}
	}

	print("Found " + compatList.blocks.Length + " compatible blocks");
	if (compatList.blocks.Length > 0) {
		auto current = compatList.GetCurrent();
		print("Current: " + current.IdName);
	}
}

void SetTargetBlock(CGameCtnBlock@ blk) {
	@compatList.targetBlock = blk;

	// Find first valid, unoccupied exit clip
	compatList.selectedExitClipIndex = 0;

	if (!IsValidRoadExitClip(0) || IsClipOccupied(0)) {
		compatList.NextExitClip();
	}

	compatList.lastConnectedClipIndex = -1;

	FindCompatibleBlocks(blk);
	auto camState = GetBlockContinuationCameraPosition(blk);
	Cam::AnimateCamTo(camState);
	UpdateGhostBlock();
}

void PlaceCurrentBlock(bool forcePlace = false) {
	auto current = compatList.GetCurrent();
	if (current is null) {
		print("No block selected");
		return;
	}

	auto ed = GetEditor(); if (ed is null) return;
	auto pmt = ed.PluginMapType;

	// Remove old ghost block if it exists
	if (tempPlacedBlock !is null) {
		auto coord = int3(tempPlacedBlock.Coord.x, tempPlacedBlock.Coord.y, tempPlacedBlock.Coord.z);
		auto dir = CGameEditorPluginMap::ECardinalDirections(int(tempPlacedBlock.BlockDir));
		pmt.RemoveGhostBlock(tempPlacedBlock.BlockInfo, coord, dir);
		@tempPlacedBlock = null;
	}

	auto coord = compatList.GetNextCoord();
	auto dir = compatList.GetNextDir();
	auto pluginDir = CGameEditorPluginMap::ECardinalDirections(int(dir));

	if (!forcePlace && !pmt.CanPlaceBlock(current, coord, pluginDir, false, 0)) {
		print("Cannot place " + current.IdName + " at position");
		return;
	}

	if (pmt.PlaceBlock(current, coord, pluginDir)) {
		print("Placed " + current.IdName);
		pmt.AutoSave();

		// Store which clip was used for this connection
		auto validClips = compatList.GetValidCandidateClips();
		if (compatList.selectedCandidateClipIndex < int(validClips.Length)) {
			compatList.lastConnectedClipIndex = validClips[compatList.selectedCandidateClipIndex];
		}

		// Find the newly placed block and make it the new target
		auto blocks = ed.Challenge.Blocks;
		for (uint i = 0; i < blocks.Length; i++) {
			auto b = cast<CGameCtnBlock>(blocks[i]);
			if (b !is null && int(b.Coord.x) == coord.x && int(b.Coord.y) == coord.y && int(b.Coord.z) == coord.z) {
				SetTargetBlock(b);
				print("New target: " + b.IdName);
				break;
			}
		}
	} else {
		print("Failed to place " + current.IdName);
	}
}

void OnExitClipChanged() {
	auto clip = compatList.GetSelectedExitClip();
	if (clip is null) return;

	print("Selected exit clip " + compatList.selectedExitClipIndex);
	print("  ClipGroupId: " + clip.ClipGroupId.Value);
	print("  ClipGroupId2: " + clip.ClipGroupId2.Value);
	print("  SymmetricalClipGroupId: " + clip.SymmetricalClipGroupId.Value);
	print("  SymmetricalClipGroupId2: " + clip.SymmetricalClipGroupId2.Value);
	print("  SymmetricalClipId: " + clip.SymmetricalClipId.Value);
	print("  Id: " + clip.Id.Value);

	// Animate camera to face the exit direction
	int exitDir = compatList.GetSelectedExitClipDirection();
	if (exitDir >= 0 && compatList.targetBlock !is null) {
		auto camState = GetBlockContinuationCameraPosition(compatList.targetBlock);
		Cam::AnimateCamTo(camState);
	}

	// Update compatible blocks for this exit
	FindCompatibleBlocks(compatList.targetBlock);
	UpdateGhostBlock();
}


CGameCtnBlock@ tempPlacedBlock = null;

void UpdateGhostBlock() {
	if (!HasEditorAndMap()) return;

	auto ed = GetEditor();
	auto pmt = ed.PluginMapType;

	// Remove old ghost block if it exists
	if (tempPlacedBlock !is null) {
		auto coord = int3(tempPlacedBlock.Coord.x, tempPlacedBlock.Coord.y, tempPlacedBlock.Coord.z);
		auto dir = CGameEditorPluginMap::ECardinalDirections(int(tempPlacedBlock.BlockDir));
		pmt.RemoveGhostBlock(tempPlacedBlock.BlockInfo, coord, dir);
		@tempPlacedBlock = null;
	}

	// Place new ghost block
	auto current = compatList.GetCurrent();
	if (current is null) return;

	auto coord = compatList.GetNextCoord();
	auto dir = compatList.GetNextDir();
	auto pluginDir = CGameEditorPluginMap::ECardinalDirections(int(dir));

	if (pmt.CanPlaceGhostBlock(current, coord, pluginDir)) {
		if (pmt.PlaceGhostBlock(current, coord, pluginDir)) {
			// Find the ghost block
			auto blocks = ed.Challenge.Blocks;
			for (uint i = 0; i < blocks.Length; i++) {
				auto b = cast<CGameCtnBlock>(blocks[i]);
				if (b !is null && int(b.Coord.x) == coord.x && int(b.Coord.y) == coord.y && int(b.Coord.z) == coord.z) {
					@tempPlacedBlock = b;
					break;
				}
			}
		}
	}
}

void ScanItemsFolder() {
	// Trackmania items are in Documents/Trackmania/Items/
	string itemsPath = IO::FromUserGameFolder("Items/");
	print("Items path: " + itemsPath);

	// Recursively scan for .Item.Gbx files
	array<string> itemFiles = IO::IndexFolder(itemsPath, true);
	print("Found " + itemFiles.Length + " items");

	for (uint i = 0; i < itemFiles.Length; i++) {
		string lower = itemFiles[i].ToLower();
		if (lower.EndsWith(".item.gbx")) {
			print("  " + itemFiles[i]);
		}
	}
}

void TestLoadItem() {
	string itemPath = "C:\\Users\\Emerson\\Documents\\Trackmania\\Items\\WTMT_RoadGrass\\UW_RG_Turn_FlatStart\\U_RG_Tur_Flat_HBLeft\\V_RG_Tur_Flat_HBLeft_Up1_Left1\\S_RG_Tur_Flat_HBLeft_Up1_Left5_Size5.Item.gbx";

	auto fid = Fids::GetFake(itemPath);

	if (fid is null) {
		print("Failed to create Fid");
		return;
	}

	if (fid.Nod is null) {
		print("Nod is null");
		return;
	}

	print("Nod type: " + Reflection::TypeOf(fid.Nod).Name);

	auto itemModel = cast<CGameItemModel>(fid.Nod);
	if (itemModel !is null) {
		print("Loaded: " + itemModel.IdName);
	}
}

void TestLoadItemFile() {
	startnew(TestLoadItemFileAsync);
}

void TestLoadItemFileAsync() {
	string itemPath = "Items\\WTMT_RoadGrass\\UW_RG_Turn_FlatStart\\U_RG_Tur_Flat_HBLeft\\V_RG_Tur_Flat_HBLeft_Up1_Left1\\S_RG_Tur_Flat_HBLeft_Up1_Left5_Size5.Item.gbx";

	print("=== Testing Item Load Methods ===");

	// Method 1: Try Fids with user game folder path
	print("\n1. Testing Fids::GetUser...");
	auto fid1 = Fids::GetUser(itemPath);
	if (fid1 !is null) {
		print("  Got Fid");
		print("  ByteSize: " + fid1.ByteSize);
		print("  Nod is null: " + (fid1.Nod is null));
		if (fid1.Nod !is null) {
			print("  Nod type: " + Reflection::TypeOf(fid1.Nod).Name);
		}
	} else {
		print("  Failed - fid is null");
	}

	// Method 2: Try through GlobalCatalog
	print("\n2. Testing GlobalCatalog...");
	auto catalog = GetApp().GlobalCatalog;
	print("  Catalog exists: " + (catalog !is null));
	// Check what's on the catalog

	// Method 3: Direct file path
	print("\n3. Testing full path...");
	string fullPath = IO::FromUserGameFolder(itemPath);
	print("  Full path: " + fullPath);
	print("  File exists: " + IO::FileExists(fullPath));

	auto fid3 = Fids::GetFake(fullPath);
	if (fid3 !is null) {
		print("  Got Fid from full path");
		print("  Nod is null: " + (fid3.Nod is null));
	}
}

void TestPlaceOneItem() {
	startnew(TestPlaceOneItemAsync);
}

void TestPlaceOneItemAsync() {
	print("Loading test item...");

	string itemPath = "Items\\WTMT_RoadGrass\\UW_RG_Turn_FlatStart\\U_RG_Tur_Flat_HBLeft\\V_RG_Tur_Flat_HBLeft_Up1_Left1\\S_RG_Tur_Flat_HBLeft_Up1_Left5_Size5.Item.gbx";

	auto fid = Fids::GetUser(itemPath);
	if (fid is null || fid.Nod is null) {
		print("Failed to load item");
		return;
	}

	auto itemModel = cast<CGameItemModel>(fid.Nod);
	if (itemModel is null) {
		print("Failed to cast to CGameItemModel");
		return;
	}

	print("Item loaded: " + itemModel.IdName);

	// Try to place it using Editor++
	vec3 position = vec3(200, 200, 200); // Some position
	vec3 rotation = vec3(0, 0, 0); // No rotation

	auto itemSpec = Editor::MakeItemSpec(itemModel, position, rotation);
	array<Editor::ItemSpec@> items = {itemSpec};

	bool success = Editor::PlaceItems(items, true);
	print("Place result: " + success);
}









enum ClipSlope {
	Flat,
	SlopeUp,
	SlopeDown,
	SlantLeft,
	SlantRight,
	DiagLeft,
	DiagRight
}

enum ClipRoadShape {
	Flat,
	RoadGrass,
	RoadDirt
}

class ClipData {
	int3 pos;
	int dir;
	ClipSlope slope;
	ClipRoadShape roadShape;
}

class ItemClipInfo {
	string itemPath;
	ClipData@[] clips;
}

dictionary g_ItemClips;  // key: item path, value: ItemClipInfo@

void InitItemDatabase() {
	string jsonPath = IO::FromStorageFolder("clipdata.json");

	// Create default file if it doesn't exist
	if (!IO::FileExists(jsonPath)) {
		print("Creating default clipdata.json");
		CreateDefaultClipData(jsonPath);
	}

	// Load the file
	IO::File file;
	file.Open(jsonPath, IO::FileMode::Read);
	string jsonStr = file.ReadToEnd();
	file.Close();

	// Parse JSON
	auto data = Json::Parse(jsonStr);
	auto items = data["items"];

	print("Loading " + items.Length + " items from clipdata.json");

	for (uint i = 0; i < items.Length; i++) {
		auto itemData = items[i];
		auto info = ItemClipInfo();
		info.itemPath = itemData["path"];

		auto clipsData = itemData["clips"];
		for (uint j = 0; j < clipsData.Length; j++) {
			auto clipData = clipsData[j];
			auto clip = ClipData();

			auto posArr = clipData["pos"];
			clip.pos = int3(posArr[0], posArr[1], posArr[2]);
			clip.dir = clipData["dir"];
			clip.slope = StringToClipSlope(clipData["slope"]);
			clip.roadShape = StringToClipRoadShape(clipData["shape"]);

			info.clips.InsertLast(clip);
		}

		g_ItemClips[info.itemPath] = info;
		print("  Loaded: " + info.itemPath + " (" + info.clips.Length + " clips)");
	}
}

void CreateDefaultClipData(const string &in path) {
	Json::Value root = Json::Object();
	Json::Value items = Json::Array();

	// Add your test item
	Json::Value item = Json::Object();
	item["path"] = "WTMT_RoadGrass/UW_RG_Turn_FlatStart/U_RG_Tur_Flat_HBLeft/V_RG_Tur_Flat_HBLeft_Up1_Left1/S_RG_Tur_Flat_HBLeft_Up1_Left5_Size5.Item.gbx";

	Json::Value clips = Json::Array();

	// Entrance clip
	Json::Value clip1 = Json::Object();
	Json::Value pos1 = Json::Array();
	pos1.Add(Json::Value(0));
	pos1.Add(Json::Value(0));
	pos1.Add(Json::Value(1));
	clip1["pos"] = pos1;
	clip1["dir"] = Json::Value(2);
	clip1["slope"] = Json::Value("Flat");
	clip1["shape"] = Json::Value("RoadGrass");
	clips.Add(clip1);

	// Exit clip
	Json::Value clip2 = Json::Object();
	Json::Value pos2 = Json::Array();
	pos2.Add(Json::Value(-9));
	pos2.Add(Json::Value(0));
	pos2.Add(Json::Value(-8));
	clip2["pos"] = pos2;
	clip2["dir"] = Json::Value(1);
	clip2["slope"] = Json::Value("SlantLeft");
	clip2["shape"] = Json::Value("RoadGrass");
	clips.Add(clip2);

	item["clips"] = clips;
	items.Add(item);
	root["items"] = items;

	// Write to file
	IO::File file;
	file.Open(path, IO::FileMode::Write);
	file.Write(Json::Write(root));
	file.Close();

	print("Created default clipdata.json at: " + path);
}

ClipSlope StringToClipSlope(const string &in s) {
	if (s == "Flat") return ClipSlope::Flat;
	if (s == "SlopeUp") return ClipSlope::SlopeUp;
	if (s == "SlopeDown") return ClipSlope::SlopeDown;
	if (s == "SlantLeft") return ClipSlope::SlantLeft;
	if (s == "SlantRight") return ClipSlope::SlantRight;
	if (s == "DiagLeft") return ClipSlope::DiagLeft;
	if (s == "DiagRight") return ClipSlope::DiagRight;
	return ClipSlope::Flat;
}

ClipRoadShape StringToClipRoadShape(const string &in s) {
	if (s == "Flat") return ClipRoadShape::Flat;
	if (s == "RoadGrass") return ClipRoadShape::RoadGrass;
	if (s == "RoadDirt") return ClipRoadShape::RoadDirt;
	return ClipRoadShape::Flat;
}






// Placable
enum PlaceableType { Block, Item }

class Placeable {
	PlaceableType type;
	string path;
	ClipData@[] clips;

	// Type-specific data (only one is set)
	CGameCtnBlockInfo@ blockInfo;
	CGameItemModel@ itemModel;

	// Size (in blocks) - needed for rotation calculations
	int3 size;
}

class CompatiblePlaceableList {
	Placeable@[] placeables;
	int currentIndex = -1;
	CGameCtnBlock@ targetBlock;  // What we're connecting to
	int selectedExitClipIndex = 0;
	int selectedCandidateClipIndex = 0;

	void Clear() {
		placeables.RemoveRange(0, placeables.Length);
		currentIndex = -1;
		@targetBlock = null;
	}

	void Add(Placeable@ p) {
		placeables.InsertLast(p);
		if (currentIndex == -1) currentIndex = 0;
	}

	void Next() {
		if (placeables.Length == 0) return;
		currentIndex = (currentIndex + 1) % placeables.Length;
		ClampCandidateClipIndex();
	}

	void Prev() {
		if (placeables.Length == 0) return;
		currentIndex = (currentIndex - 1 + placeables.Length) % placeables.Length;
		ClampCandidateClipIndex();
	}

	void ClampCandidateClipIndex() {
		auto current = GetCurrent();
		if (current is null) {
			selectedCandidateClipIndex = 0;
			return;
		}
		if (selectedCandidateClipIndex >= int(current.clips.Length)) {
			selectedCandidateClipIndex = current.clips.Length - 1;
		}
		if (selectedCandidateClipIndex < 0) selectedCandidateClipIndex = 0;
	}

	Placeable@ GetCurrent() {
		if (currentIndex < 0 || currentIndex >= int(placeables.Length)) return null;
		return placeables[currentIndex];
	}

	vec3 GetNextWorldPos() {
		// Calculate world position based on exit clip and candidate entry clip
		if (targetBlock is null) return vec3(0);

		auto current = GetCurrent();
		if (current is null || selectedCandidateClipIndex >= int(current.clips.Length)) {
			return Editor::CoordToPos(targetBlock.Coord);
		}

		// Get exit clip position in world coords
		auto exitClipInfo = GetExitClipWithUnit();
		if (exitClipInfo is null) return Editor::CoordToPos(targetBlock.Coord);

		int3 targetCoord = int3(targetBlock.Coord.x, targetBlock.Coord.y, targetBlock.Coord.z);
		int targetDir = int(targetBlock.BlockDir);
		int3 exitOffset = int3(exitClipInfo.unit.Offset.x, exitClipInfo.unit.Offset.y, exitClipInfo.unit.Offset.z);

		auto targetSize = targetBlock.BlockInfo.VariantBaseAir.Size;
		int3 targetSizeI = int3(targetSize.x, targetSize.y, targetSize.z);
		int3 rotatedExitOffset = RotateOffset(exitOffset, targetDir, targetSizeI);

		int exitClipDir = GetExitClipDirection();
		if (exitClipDir < 0) return Editor::CoordToPos(targetBlock.Coord);

		// Exit clip position in world
		vec3 exitClipWorldPos = Editor::CoordToPos(targetCoord + rotatedExitOffset);

		// Move one block in exit direction to get connection point
		vec3 connectionPoint = exitClipWorldPos + DirToVector(exitClipDir) * 32.0f;

		// Get candidate entry clip
		auto entryClip = current.clips[selectedCandidateClipIndex];
		int candidateDir = GetNextRotation();

		// Rotate entry clip offset
		int3 entryOffset = entryClip.pos;
		int3 rotatedEntryOffset = RotateOffset(entryOffset, candidateDir, current.size);

		// Candidate position = connection point - rotated entry offset
		vec3 candidatePos = connectionPoint - vec3(rotatedEntryOffset.x, rotatedEntryOffset.y, rotatedEntryOffset.z) * 32.0f;

		return candidatePos;
	}

	vec3 GetNextRotation() {
		if (targetBlock is null) return vec3(0);

		auto current = GetCurrent();
		if (current is null || selectedCandidateClipIndex >= int(current.clips.Length)) {
			return vec3(0);
		}

		int exitDir = GetExitClipDirection();
		auto entryClip = current.clips[selectedCandidateClipIndex];
		int entryDir = entryClip.dir;

		if (exitDir < 0 || entryDir < 0) return vec3(0);

		// Calculate yaw rotation
		int rotation = (exitDir - entryDir + 2 + 4) % 4;
		float yaw = rotation * Math::PI / 2.0f;

		return vec3(0, yaw, 0);  // pitch, yaw, roll
	}

	// Helper functions
	ClipWithUnit@ GetSelectedExitClipWithUnit() {
		if (targetBlock is null) return null;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return null;

		int clipCount = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			if (clipCount + int(unit.AllClips.Length) > selectedExitClipIndex) {
				auto result = ClipWithUnit();
				@result.clip = unit.AllClips[selectedExitClipIndex - clipCount];
				@result.unit = unit;
				result.unitIndex = u;
				result.localClipIndex = selectedExitClipIndex - clipCount;
				return result;
			}
			clipCount += unit.AllClips.Length;
		}
		return null;
	}

	int GetExitClipDirection() {
		// Same as before
		// (Copy from your existing GetSelectedExitClipDirection)
		return -1; // TODO
	}

	void CycleExitClip(int direction) {
		// Same as before
		// (Copy from your existing CycleExitClip)
	}

	void NextCandidateClip() {
		auto current = GetCurrent();
		if (current is null || current.clips.Length == 0) return;
		selectedCandidateClipIndex = (selectedCandidateClipIndex + 1) % current.clips.Length;
	}

	void PrevCandidateClip() {
		auto current = GetCurrent();
		if (current is null || current.clips.Length == 0) return;
		selectedCandidateClipIndex = (selectedCandidateClipIndex - 1 + current.clips.Length) % current.clips.Length;
	}
}

vec3 DirToVector(int dir) {
	if (dir == 0) return vec3(0, 0, 1);   // North
	if (dir == 1) return vec3(1, 0, 0);   // East
	if (dir == 2) return vec3(0, 0, -1);  // South
	if (dir == 3) return vec3(-1, 0, 0);  // West
	return vec3(0);
}

// Global instance
CompatiblePlaceableList compatList;







CGameCtnAnchoredObject@ previewItemObj;
CGameItemModel@ previewItemModel;
vec3 previewPos;
vec3 previewRot;
bool showingPreview = false;

void ShowItemPreview(CGameItemModel@ item, vec3 pos, vec3 rot) {
	HideItemPreview();

	auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
	auto map = editor.Challenge;
	uint beforeCount = map.AnchoredObjects.Length;

	auto itemSpec = Editor::MakeItemSpec(item, pos, rot);
	array<Editor::ItemSpec@> items = {itemSpec};
	bool placed = Editor::PlaceItems(items, false);

	if (placed && map.AnchoredObjects.Length > beforeCount) {
		@previewItemObj = map.AnchoredObjects[map.AnchoredObjects.Length - 1];
		@previewItemModel = item;
		previewPos = pos;
		previewRot = rot;
		showingPreview = true;
	}
}

bool PreviewItemStillExists() {
	auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
	auto map = editor.Challenge;

	bool found = false;
	for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
		if (map.AnchoredObjects[i] is previewItemObj) {
			found = true;
			break;
		}
	}
	if (!found) {
		print("Preview item no longer exists in map");
	}
	return found;
}

void HideItemPreview() {
	if (!showingPreview || previewItemObj is null) return;
	if (PreviewItemStillExists()) {
		array<CGameCtnAnchoredObject@> toDelete = {previewItemObj};
		Editor::DeleteItems(toDelete, false);
	}
	@previewItemObj = null;
	@previewItemModel = null;
	showingPreview = false;
}

void PlaceItem() {
	if (!showingPreview || previewItemModel is null) return;

	// Store the data before clearing
	auto model = previewItemModel;
	auto pos = previewPos;
	auto rot = previewRot;

	// Remove the preview (placed without undo)
	HideItemPreview();

	// Place it again with undo enabled
	auto itemSpec = Editor::MakeItemSpec(model, pos, rot);
	array<Editor::ItemSpec@> items = {itemSpec};
	Editor::PlaceItems(items, true);
}

void TestShowPreview() {
	string itemPath = "Items\\WTMT_RoadGrass\\UW_RG_Turn_FlatStart\\U_RG_Tur_Flat_HBLeft\\V_RG_Tur_Flat_HBLeft_Up1_Left1\\S_RG_Tur_Flat_HBLeft_Up1_Left5_Size5.Item.gbx";

	auto fid = Fids::GetUser(itemPath);
	auto itemModel = cast<CGameItemModel>(fid.Nod);

	if (itemModel !is null) {
		ShowItemPreview(itemModel, vec3(200, 50, 200), vec3(0, 0, 0));
		print("Preview shown");
	}
}

void DrawClipPreview(vec3 clipPos) {
	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_preview");

	drawInst.Reset(); // Clear previous drawings

	// Draw a box around the clip position
	float size = 3.0;
	vec3 min = clipPos - vec3(size, size, size) + vec3(0, 64, 0);
	vec3 max = clipPos + vec3(size, size, size) + vec3(0, 64, 0);

	// Draw box edges as line segments
	// Bottom face
	drawInst.PushLineSegment(vec3(min.x, min.y, min.z), vec3(max.x, min.y, min.z));
	drawInst.PushLineSegment(vec3(max.x, min.y, min.z), vec3(max.x, min.y, max.z));
	drawInst.PushLineSegment(vec3(max.x, min.y, max.z), vec3(min.x, min.y, max.z));
	drawInst.PushLineSegment(vec3(min.x, min.y, max.z), vec3(min.x, min.y, min.z));

	// Top face
	drawInst.PushLineSegment(vec3(min.x, max.y, min.z), vec3(max.x, max.y, min.z));
	drawInst.PushLineSegment(vec3(max.x, max.y, min.z), vec3(max.x, max.y, max.z));
	drawInst.PushLineSegment(vec3(max.x, max.y, max.z), vec3(min.x, max.y, max.z));
	drawInst.PushLineSegment(vec3(min.x, max.y, max.z), vec3(min.x, max.y, min.z));

	// Vertical edges
	drawInst.PushLineSegment(vec3(min.x, min.y, min.z), vec3(min.x, max.y, min.z));
	drawInst.PushLineSegment(vec3(max.x, min.y, min.z), vec3(max.x, max.y, min.z));
	drawInst.PushLineSegment(vec3(max.x, min.y, max.z), vec3(max.x, max.y, max.z));
	drawInst.PushLineSegment(vec3(min.x, min.y, max.z), vec3(min.x, max.y, max.z));

	drawInst.RequestLineColor(vec3(1, 0, 0)); // Red
	drawInst.Draw(); // Must call every frame
}
void HideClipPreview() {
	auto drawInst = Editor::DrawLinesAndQuads::GetOrCreateDrawInstance("compatiblocks_preview");
	drawInst.Deregister();
}















// Externally called functions

void RenderInterface() {
	if (!HasEditorAndMap()) return;
	bool open = true;
	UI::Begin("Compatiblocks", open, UI::WindowFlags::AlwaysAutoResize);

	auto ed = GetEditor();
	if (ed !is null) {
		auto pmt = ed.PluginMapType;
		if (pmt !is null) {
			pmt.EnableAirMapping = UI::Checkbox("Enable Air Mapping", pmt.EnableAirMapping);
		}
	}

	UI::Separator();
	UI::Text("Exit Clip Selection:");
	if (UI::Button("< Prev Exit")) {
		compatList.PrevExitClip();
		OnExitClipChanged();
	}
	UI::SameLine();
	UI::Text("Clip " + compatList.selectedExitClipIndex);
	UI::SameLine();
	if (UI::Button("Next Exit >")) {
		compatList.NextExitClip();
		OnExitClipChanged();
	}

	UI::Text("Block Selection:");
	if (UI::Button("< Prev Block")) {
		compatList.Prev();
		auto current = compatList.GetCurrent();
		if (current !is null) {
			print("Previous: " + current.IdName);
			UpdateGhostBlock();
		}
	}
	UI::SameLine();
	auto current = compatList.GetCurrent();
	UI::Text(current !is null ? current.IdName : "None");
	UI::SameLine();
	if (UI::Button("Next Block >")) {
		compatList.Next();
		auto current = compatList.GetCurrent();
		if (current !is null) {
			print("Next: " + current.IdName);
			UpdateGhostBlock();
		}
	}

	UI::Text("Candidate Clip Selection:");
	if (UI::Button("< Prev Clip")) {
		compatList.PrevCandidateClip();
		print("Selected candidate clip: " + compatList.selectedCandidateClipIndex);
		UpdateGhostBlock();
	}
	UI::SameLine();
	UI::Text("Clip " + compatList.selectedCandidateClipIndex);
	UI::SameLine();
	if (UI::Button("Next Clip >")) {
		compatList.NextCandidateClip();
		print("Selected candidate clip: " + compatList.selectedCandidateClipIndex);
		UpdateGhostBlock();
	}

	UI::Separator();
	if (UI::Button("Place Block")) { PlaceCurrentBlock(); }
	UI::SameLine();
	if (UI::Button("Force Place")) { PlaceCurrentBlock(true); }

	Cam::CamState cs = Cam::GetCurrentCamState();
	UI::Text("Target:  " + cs.Pos.x + ", " + cs.Pos.y + ", " + cs.Pos.z);
	UI::Text("Angles:  H=" + cs.HAngle + "  V=" + cs.VAngle);
	UI::Text("Dist:    " + cs.TargetDist);

	UI::Separator();
	if (UI::Button("Print All Clips of Target Block")) {
		PrintAllBlockClips(compatList.targetBlock);
	}
	if (UI::Button("List All Items in Map")) {
		ListAllItemsInMap();
	}
	if (UI::Button("Scan Items Folder")) {
		ScanItemsFolder();
	}
	if (UI::Button("Test Load Item")) {
		TestLoadItem();
	}
	if (UI::Button("Test Load Item File")) {
		TestLoadItemFile();
	}
	if (UI::Button("Test Place One Item")) {
		TestPlaceOneItem();
	}
	if (UI::Button("Show Preview")) {
		startnew(TestShowPreview);
		DrawClipPreview(vec3(200, 200, 200));
	}
	if (UI::Button("Hide Preview")) {
		HideItemPreview();
		HideClipPreview();
	}
	if (UI::Button("Place Item")) {
		PlaceItem();
	}


	UI::End();
}

mixin class KeyHook { void OnKeyPress(bool down, VirtualKey key) { ::OnKeyPress(down, key); } }
void OnKeyPress(bool down, VirtualKey key) {
	if (!down || !HasEditorAndMap()) { return; }

	if (key == VirtualKey::C) {
		CGameCtnBlock@ blk = GetClosestBlock();
		if (blk is null) {
			print("No block found");
			return;
		}
		FindCompatibleBlocks(blk);
		Cam::CamState dst = GetBlockContinuationCameraPosition(blk);
		Cam::AnimateCamTo(dst);
		SetTargetBlock(blk);
	}

	if (key == VirtualKey::OemComma) {
		compatList.Prev();
		auto current = compatList.GetCurrent();
		if (current !is null) {
			print("Previous: " + current.IdName);
			UpdateGhostBlock();
		}
	}

	if (key == VirtualKey::OemPeriod) {
		compatList.Next();
		auto current = compatList.GetCurrent();
		if (current !is null) {
			print("Next: " + current.IdName);
			UpdateGhostBlock();
		}
	}

	if (key == VirtualKey::Oem2) { // '/' key
		PrintBlockInfo(compatList.GetCurrent(), true);
		PlaceCurrentBlock();
	}
}

void Main() {
	InitItemDatabase();

	while (true) {
		if (HasEditorAndMap()) {
			auto ed = GetEditor();
			if (ed !is null) {
				auto pmt = ed.PluginMapType;
				if (pmt !is null) {
					// Automatically enable mix mapping (ghost blocks)
					pmt.EnableMixMapping = true;
				}
			}

			Cam::UpdateAnimAndCamera();
		}
		yield();
	}
}






// Trash

void ListAvailableBlocks() {
	auto ed = GetEditor(); if (ed is null) { return; }
	auto pmt = ed.PluginMapType;
	// for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
	// 	auto block = pmt.ClassicBlocks[i];
	// 	auto info = block.BlockInfo;
	// 	print("Block " + i + ": " + info.IdName + " / " + info.NameE + " by " + info.Author.GetName() +
	// 		" (VariantAir Size: " + info.VariantBaseAir.Size.x + "," + info.VariantBaseAir.Size.y + "," + info.VariantBaseAir.Size.z +
	// 		"; VariantGround Size: " + info.VariantBaseGround.Size.x + "," + info.VariantBaseGround.Size.y + "," + info.VariantBaseGround.Size.z + ")");
	// }
	for (uint i = 0; i < pmt.BlockModels.Length; i++) {
		auto info = pmt.BlockModels[i];
		print("Block " + i + ": " + info.IdName + " / " + info.NameE + " by " + info.Author.GetName() +
			" (VariantAir Size: " + info.VariantBaseAir.Size.x + "," + info.VariantBaseAir.Size.y + "," + info.VariantBaseAir.Size.z +
			"; VariantGround Size: " + info.VariantBaseGround.Size.x + "," + info.VariantBaseGround.Size.y + "," + info.VariantBaseGround.Size.z + ")");
	}

}

void AnalyzeBlockClips(CGameCtnBlock@ block) {
	if (block is null) return;
	print("=== Analyzing Clips ===");
	print("Block Dir: " + block.BlockDir);

	for (uint i = 0; i < block.BlockUnits.Length; i++) {
		auto unit = block.BlockUnits[i];
		if (unit is null || unit.BlockUnitModel is null) continue;
		auto model = unit.BlockUnitModel;

		print("Unit " + i + ":");
		print("  North: " + model.ClipCount_North + ", South: " + model.ClipCount_South);

		// Try to get the actual clips
		if (model.Clips_North.Length > 0) {
			auto clip = model.Clips_North[0];
			if (clip !is null) {
				print("  North clip[0] IdName: " + clip.IdName);
			}
		}
		if (model.Clips_South.Length > 0) {
			auto clip = model.Clips_South[0];
			if (clip !is null) {
				print("  South clip[0] IdName: " + clip.IdName);
			}
		}
		if (model.Clips_Bottom.Length > 0) {
			auto clip = model.Clips_Bottom[0];
			if (clip !is null) {
				print("  Bottom clip[0] IdName: " + clip.IdName);
			}
		}
	}
}

void AnalyzeBlock(CGameCtnBlock@ block) {
	if (block is null) { return; }
	auto info = block.BlockInfo;

	print("=== Block Analysis ===");
	print("IdName: " + info.IdName);
	print("Name: " + info.Name);
	print("IsRoad: " + info.IsRoad);
	print("IsPillar: " + info.IsPillar);
	print("Dir: " + info.Dir);
	print("SymmetricalBlockInfoId: " + info.SymmetricalBlockInfoId.Value);

	// Size info
	if (block.IsGround && info.VariantBaseGround !is null) {
		auto size = info.VariantBaseGround.Size;
		print("Ground Size: " + size.x + "," + size.y + "," + size.z);
	}
	if (!block.IsGround && info.VariantBaseAir !is null) {
		auto size = info.VariantBaseAir.Size;
		print("Air Size: " + size.x + "," + size.y + "," + size.z);
	}

	// Placement info
	print("Block Coord: " + block.Coord.x + "," + block.Coord.y + "," + block.Coord.z);
	print("Block Dir: " + block.BlockDir);

	// Check symmetrical connection
	if (info.SymmetricalBlockInfoConnected !is null) {
		print("Has symmetrical connection: " + info.SymmetricalBlockInfoConnected.IdName);
	}
}


void AnalyzeBlockInfoClips(CGameCtnBlockInfo@ info) {
	if (info is null) return;
	print("=== Analyzing BlockInfo Clips: " + info.IdName + " ===");

	auto variant = info.VariantBaseAir;
	if (variant is null) return;

	for (uint i = 0; i < variant.BlockUnitInfos.Length; i++) {
		auto unitInfo = variant.BlockUnitInfos[i];
		if (unitInfo is null) continue;

		print("Unit " + i + ":");
		print("  AllClips: " + unitInfo.AllClips.Length);

		if (unitInfo.AllClips.Length > 0) {
			auto clip = unitInfo.AllClips[0];
			if (clip !is null) {
				print("  Clip[0]: ClipGroupId=" + clip.ClipGroupId.Value);
				print("  Clip[0]: SymmetricalClipGroupId=" + clip.SymmetricalClipGroupId.Value);
			}
		}
	}
}





























































class CompatiblePlaceableList {
	Placeable@[] placeables;
	int currentIndex = -1;
	CGameCtnBlock@ targetBlock;
	int selectedExitClipIndex = 0;
	int selectedCandidateClipIndex = 0;
	int lastConnectedClipIndex = -1;

	void Clear() {
		placeables.RemoveRange(0, placeables.Length);
		currentIndex = -1;
		@targetBlock = null;
	}

	void Add(Placeable@ p) {
		placeables.InsertLast(p);
		if (currentIndex == -1) currentIndex = 0;
	}

	void Next() {
		if (placeables.Length == 0) return;
		currentIndex = (currentIndex + 1) % placeables.Length;
		ClampCandidateClipIndex();
	}

	void Prev() {
		if (placeables.Length == 0) return;
		currentIndex = (currentIndex - 1 + placeables.Length) % placeables.Length;
		ClampCandidateClipIndex();
	}

	void ClampCandidateClipIndex() {
		auto current = GetCurrent();
		if (current is null) {
			selectedCandidateClipIndex = 0;
			return;
		}
		if (selectedCandidateClipIndex >= int(current.clips.Length)) {
			selectedCandidateClipIndex = current.clips.Length - 1;
		}
		if (selectedCandidateClipIndex < 0) selectedCandidateClipIndex = 0;
	}

	Placeable@ GetCurrent() {
		if (currentIndex < 0 || currentIndex >= int(placeables.Length)) return null;
		return placeables[currentIndex];
	}

	void NextCandidateClip() {
		auto current = GetCurrent();
		if (current is null || current.clips.Length == 0) return;
		selectedCandidateClipIndex = (selectedCandidateClipIndex + 1) % current.clips.Length;
	}

	void PrevCandidateClip() {
		auto current = GetCurrent();
		if (current is null || current.clips.Length == 0) return;
		selectedCandidateClipIndex = (selectedCandidateClipIndex - 1 + current.clips.Length) % current.clips.Length;
	}

	vec3 GetNextWorldPos() {
		if (targetBlock is null) return vec3(0);

		auto current = GetCurrent();
		if (current is null || selectedCandidateClipIndex >= int(current.clips.Length)) {
			return Editor::CoordToPos(targetBlock.Coord);
		}

		// Get exit clip info
		auto exitClipInfo = GetSelectedExitClipWithUnit();
		if (exitClipInfo is null) return Editor::CoordToPos(targetBlock.Coord);

		// Target block's coord and direction
		int3 targetCoord = int3(targetBlock.Coord.x, targetBlock.Coord.y, targetBlock.Coord.z);
		int targetDir = int(targetBlock.BlockDir);

		// Exit clip offset, rotated
		int3 exitOffset = int3(exitClipInfo.unit.Offset.x, exitClipInfo.unit.Offset.y, exitClipInfo.unit.Offset.z);
		auto targetSize = targetBlock.BlockInfo.VariantBaseAir.Size;
		int3 targetSizeI = int3(targetSize.x, targetSize.y, targetSize.z);
		int3 rotatedExitOffset = RotateOffset(exitOffset, targetDir, targetSizeI);

		// Exit clip direction
		int exitClipDir = GetSelectedExitClipDirection();
		if (exitClipDir < 0) return Editor::CoordToPos(targetBlock.Coord);

		// Exit clip world position
		vec3 exitClipWorldPos = Editor::CoordToPos(targetCoord + rotatedExitOffset);

		// Connection point (one block forward)
		vec3 connectionPoint = exitClipWorldPos + DirToVector(exitClipDir) * 32.0f;

		// Get candidate entry clip
		auto entryClip = current.clips[selectedCandidateClipIndex];
		float yaw = GetNextYawRotation();
		int candidateDir = int((yaw / (Math::PI / 2.0f)) + 0.5f) % 4;

		// Rotate entry clip offset
		int3 entryOffset = entryClip.pos;
		int3 rotatedEntryOffset = RotateOffset(entryOffset, candidateDir, current.size);

		// Candidate position
		vec3 candidatePos = connectionPoint - vec3(rotatedEntryOffset.x, rotatedEntryOffset.y, rotatedEntryOffset.z) * 32.0f;

		return candidatePos;
	}

	float GetNextYawRotation() {
		if (targetBlock is null) return 0;

		auto current = GetCurrent();
		if (current is null || selectedCandidateClipIndex >= int(current.clips.Length)) {
			return 0;
		}

		int exitDir = GetSelectedExitClipDirection();
		auto entryClip = current.clips[selectedCandidateClipIndex];
		int entryDir = entryClip.dir;

		if (exitDir < 0 || entryDir < 0) return 0;

		// Calculate rotation so entry faces opposite of exit
		int rotation = (exitDir - entryDir + 2 + 4) % 4;
		return rotation * Math::PI / 2.0f;
	}

	vec3 GetNextRotation() {
		return vec3(0, GetNextYawRotation(), 0);  // pitch, yaw, roll
	}

	ClipWithUnit@ GetSelectedExitClipWithUnit() {
		if (targetBlock is null) return null;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return null;

		int globalIndex = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;

			for (uint c = 0; c < unit.AllClips.Length; c++) {
				if (globalIndex == selectedExitClipIndex) {
					auto result = ClipWithUnit();
					@result.clip = unit.AllClips[c];
					@result.unit = unit;
					result.unitIndex = u;
					result.localClipIndex = c;
					return result;
				}
				globalIndex++;
			}
		}
		return null;
	}

	int GetSelectedExitClipDirection() {
		auto clipInfo = GetSelectedExitClipWithUnit();
		if (clipInfo is null || clipInfo.clip is null) return -1;
		return GetClipDirection(targetBlock.BlockInfo, selectedExitClipIndex);
	}

	void CycleExitClip(int direction) {
		if (targetBlock is null) return;
		auto variant = targetBlock.BlockInfo.VariantBaseAir;
		if (variant is null) return;

		int totalClips = 0;
		for (uint u = 0; u < variant.BlockUnitInfos.Length; u++) {
			auto unit = variant.BlockUnitInfos[u];
			if (unit is null) continue;
			totalClips += unit.AllClips.Length;
		}

		if (totalClips == 0) return;

		int attempts = 0;
		do {
			selectedExitClipIndex = (selectedExitClipIndex + direction + totalClips) % totalClips;
			attempts++;

			auto clipInfo = GetSelectedExitClipWithUnit();
			if (clipInfo !is null && clipInfo.clip !is null) {
				int clipDir = GetSelectedExitClipDirection();
				if (clipDir >= 0) {
					print("Selected exit clip " + selectedExitClipIndex + " facing direction " + clipDir);
					return;
				}
			}
		} while (attempts < totalClips);
	}
}
