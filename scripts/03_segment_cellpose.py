"""Step 3 - Cellpose segmentation of cells and nuclei.

Reads   <dir>/Temporary/*_sum_bin_clahe_c1.tif   (output of step 2)
Writes  <dir>/Processed/masks/<name>_cell.tif and <name>_nuc.tif  (label images)

Usage:
    python 03_segment_cellpose.py --dir raw_data/Crops --model_path models
"""
import argparse
import os

import numpy as np
from cellpose import io, models

CELL_MODEL = "CP_20250425_cells_bin3_sumJN"
NUC_MODEL = "CP_20250425_nuc_bin3_sumJN02"
SUFFIX = "_sum_bin_clahe_c1.tif"
CHANNELS = [0, 0]  # single grayscale channel


def save_masks(masks, path, label):
    if len(np.unique(masks)) > 1:
        # uint8 is expected by step 4 (max. 255 objects per crop)
        io.imsave(path, masks.astype("uint8"))
        print(f"{label} masks saved: {os.path.basename(path)}")
    else:
        print(f"No {label.lower()} found.")


def main(dir, model_path):
    input_folder = os.path.join(dir, "Temporary")
    output_folder = os.path.join(dir, "Processed", "masks")
    os.makedirs(output_folder, exist_ok=True)

    cell_model = models.CellposeModel(pretrained_model=os.path.join(model_path, CELL_MODEL))
    nuc_model = models.CellposeModel(pretrained_model=os.path.join(model_path, NUC_MODEL))

    print("Starting segmentation!")
    for f in sorted(os.listdir(input_folder)):
        if not f.endswith(SUFFIX):
            continue
        image = io.imread(os.path.join(input_folder, f))

        cell_masks, _, _ = cell_model.eval(image, channels=CHANNELS)
        save_masks(cell_masks, os.path.join(output_folder, f.replace(SUFFIX, "_cell.tif")), "Cell")

        nuc_masks, _, _ = nuc_model.eval(image, channels=CHANNELS)
        save_masks(nuc_masks, os.path.join(output_folder, f.replace(SUFFIX, "_nuc.tif")), "Nuclei")

    print("*** Segmentation finished! ***")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Segment cells and nuclei in cropped images.")
    parser.add_argument("--dir", required=True, help="Folder with cropped images (contains 'Temporary/' from step 2).")
    parser.add_argument("--model_path", required=True, help="Folder with the trained Cellpose models.")
    args = parser.parse_args()
    main(args.dir, args.model_path)
