import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

df = pd.read_csv("split_phoneme_datasets/A_frames.csv")  # or P/U/etc
# IMPORTANT: this file now needs to include attempt_id (regenerate splits after you add attempt_id)

feature_cols = [
    "lip_gap_norm",
    "mouth_height_norm",
    "round_ratio",
    "lip_gap_prev_norm",
    "lip_gap_delta_norm",
    "mouth_height_delta_norm"
]

# clean
df = df.replace([np.inf, -np.inf], np.nan)
df = df.dropna(subset=feature_cols + ["class_label", "attempt_id"])

# encode labels
le = LabelEncoder()
df["class_id"] = le.fit_transform(df["class_label"])

# build attempt table
attempt_table = df[["attempt_id", "class_label"]].drop_duplicates()

attempt_trainval, attempt_test = train_test_split(
    attempt_table,
    test_size=0.15,
    random_state=42,
    stratify=attempt_table["class_label"]
)

attempt_train, attempt_val = train_test_split(
    attempt_trainval,
    test_size=0.1765,
    random_state=42,
    stratify=attempt_trainval["class_label"]
)

train_ids = set(attempt_train["attempt_id"])
val_ids   = set(attempt_val["attempt_id"])
test_ids  = set(attempt_test["attempt_id"])

train_df = df[df["attempt_id"].isin(train_ids)].reset_index(drop=True)
val_df   = df[df["attempt_id"].isin(val_ids)].reset_index(drop=True)
test_df  = df[df["attempt_id"].isin(test_ids)].reset_index(drop=True)

X_train = train_df[feature_cols].to_numpy(np.float32)
y_train = train_df["class_id"].to_numpy(int)

X_val   = val_df[feature_cols].to_numpy(np.float32)
y_val   = val_df["class_id"].to_numpy(int)

X_test  = test_df[feature_cols].to_numpy(np.float32)
y_test  = test_df["class_id"].to_numpy(int)
