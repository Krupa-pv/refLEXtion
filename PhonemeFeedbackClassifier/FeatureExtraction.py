import json
import os
import glob
import uuid
import pandas as pd
import math 

folder_path = 'Data'
json_pattern = os.path.join(folder_path, '*.jsonl')
json_files = glob.glob(json_pattern)

rows = []  # we'll collect dicts here

for file_path in json_files:
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue  # skip blank lines
            try:
                obj = json.loads(line)  # parse one JSON object from this line
                rows.append(obj)
            except Exception as e:
                print('json loading error in', file_path, e)

# Now build a DataFrame directly from the list of dicts
df = pd.DataFrame(rows)

print(df.head())
print(f"Loaded {len(df)} rows from {len(json_files)} files")

all_top_keys = set()

for frames_list in df['frames']:
    if isinstance(frames_list, list):
        for frame in frames_list:
            if isinstance(frame, dict):
                #print(frame['mouthContours'].keys())
                all_top_keys.update(frame.keys())

print("Unique top-level keys in frames:", all_top_keys)


# ====== Feature Extraction =======
import math
import pandas as pd

def centroid(points):
    if not points:
        return None
    sx = sy = 0.0
    n = 0
    for p in points:
        if 'x' in p and 'y' in p:
            sx += p['x']
            sy += p['y']
            n += 1
    if n == 0:
        return None
    return (sx / n, sy / n)

def vertical_distance(p1, p2):
    if p1 is None or p2 is None:
        return None
    return abs(p1[1] - p2[1])

def euclidean_distance(p1, p2):
    if p1 is None or p2 is None:
        return None
    dx = p1[0] - p2[0]
    dy = p1[1] - p2[1]
    return math.sqrt(dx * dx + dy * dy)

def mouth_corners(points):
    if not points:
        return (None, None)
    left = min(points, key=lambda p: p.get('x', float('inf')))
    right = max(points, key=lambda p: p.get('x', float('-inf')))
    if 'x' in left and 'y' in left and 'x' in right and 'y' in right:
        return ((left['x'], left['y']), (right['x'], right['y']))
    return (None, None)

def extract_frame_features_single(frame_dict, prev_feats=None):
    ts = frame_dict.get("timestamp")
    frame_idx = frame_dict.get("frame_index")
    mc = frame_dict.get("mouthContours", {}) or {}

    upperLipBottom = mc.get("upperLipBottom")
    lowerLipTop = mc.get("lowerLipTop")
    upperLipTop = mc.get("upperLipTop")
    lowerLipBottom = mc.get("lowerLipBottom")

    upBotCenter = centroid(upperLipBottom)
    lowTopCenter = centroid(lowerLipTop)
    upTopCenter = centroid(upperLipTop)
    lowBotCenter = centroid(lowerLipBottom)

    lip_gap = vertical_distance(upBotCenter, lowTopCenter)
    mouth_height = vertical_distance(upTopCenter, lowBotCenter)

    ref = lowerLipTop if (lowerLipTop and len(lowerLipTop) > 0) else upperLipBottom
    left_corner, right_corner = mouth_corners(ref)
    mouth_width = euclidean_distance(left_corner, right_corner)

    if not mouth_width or mouth_width == 0 or lip_gap is None or mouth_height is None:
        return None

    lip_gap_norm = lip_gap / mouth_width
    mouth_height_norm = mouth_height / mouth_width
    round_ratio = mouth_width / mouth_height if mouth_height > 0 else float("inf")

    if prev_feats:
        lip_gap_prev_norm = prev_feats["lip_gap_norm"]
        lip_gap_delta_norm = lip_gap_norm - lip_gap_prev_norm
        mouth_height_prev_norm = prev_feats["mouth_height_norm"]
        mouth_height_delta_norm = mouth_height_norm - mouth_height_prev_norm
    else:
        lip_gap_prev_norm = lip_gap_norm
        lip_gap_delta_norm = 0.0
        mouth_height_prev_norm = mouth_height_norm
        mouth_height_delta_norm = 0.0

    return {
        "timestamp": ts,
        "frame_index": frame_idx,
        "lip_gap_norm": lip_gap_norm,
        "mouth_height_norm": mouth_height_norm,
        "round_ratio": round_ratio,
        "lip_gap_prev_norm": lip_gap_prev_norm,
        "lip_gap_delta_norm": lip_gap_delta_norm,
        "mouth_height_delta_norm": mouth_height_delta_norm
    }

def explode_attempts_to_frames(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for _, row in df.iterrows():
        phoneme = row["phoneme"]
        label = row["quality_label"]
        frames = row["frames"]

        # make a stable unique attempt_id for this attempt
        attempt_id = str(uuid.uuid4())

        prev_feats = None
        for frame_dict in frames:
            feats = extract_frame_features_single(frame_dict, prev_feats=prev_feats)
            if feats is None:
                continue

            rows.append({
                "attempt_id": attempt_id,
                "phoneme": phoneme,
                "class_label": label,
                **feats
            })
            prev_feats = feats

    return pd.DataFrame(rows)


#extract features
features = explode_attempts_to_frames(df)
features.to_csv('features.csv', index = False)


