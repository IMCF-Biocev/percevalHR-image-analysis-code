# PercevalHR ratio image analysis code

> Image analysis and quantification code for PercevalHR imaging experiments.

>The pipeline computes PercevalHR ATP:ADP ratio images from 2-channel confocal Z-stacks, segments cells and nuclei (Cellpose) and exports per-pixel ratio values together with their geodesic distance from the nucleus.

## Repository structure

```
raw_data/                 place raw .nd2 files here
scripts/
  01_make_crops.ijm                     Fiji, interactive – crop cells from raw stacks
  02_ratio_images.ijm                   Fiji, batch – generate ratio images + processed intermediate images for segmentation
  03_segment_cellpose.py                Python – Cellpose segmentation of cells/nuclei
  04_masks_and_distance_analysis.ijm    Fiji, interactive – check masks, compute distance map, export table
models/                   trained Cellpose models (cells, nuclei)
cellpose_training/        images + masks used to train the models
SOFTWARE_VERSIONS.md      software and package versions
```

## Input data

Raw data are not part of this repository. Copy the `.nd2` files into `raw_data/`.

Expected format (Nikon NIS-Elements `.nd2`): 2D + Z stack, 2 channels, 16-bit


## Running the pipeline

Fiji macros (`.ijm`) are run by dragging the file onto the Fiji window (or *File › Open*) and pressing **Run**
in the script editor. Each macro starts by asking for a folder. All outputs are written inside input ~ `raw_data/`.

### Step 1 – Crop cells (`01_make_crops.ijm`, interactive)

1. Run the macro and select the `raw_data/` folder.
2. A max projection of the first image is shown. Draw a rectangle around a cell (≥ ~100 px margin) and press
   **Ctrl+T** to add it to the ROI Manager. Repeat for every cell you want to analyze.
3. Press **OK** to save the crops and continue with the next image. Pressing OK with no ROI skips the image.

Crops are saved to `raw_data/Crops/`, the crop position is stored in the file name.

### Step 2 – Ratio images (`02_ratio_images.ijm`, automatic)

1. Run the macro and select `raw_data/Crops/`.
2. All crops are processed without further input.

Each channel is median-filtered (r = 1), sum-projected and binned 3 × 3. The ratio is computed as (C1 − C2) / (C1 + C2).
Ratio images (`*_ratio.tif`) and previews (`*_report.jpg`) go to `Crops/Processed/`, images for segmentation to
`Crops/Temporary/`.

### Step 3 – Segment cells and nuclei (`03_segment_cellpose.py`)

Check `SOFTWARE_VERSIONS.md` to find used python and package versions.

In a terminal, from the repository folder:
```
python scripts/03_segment_cellpose.py --dir raw_data/Crops --model_path models
```
Masks are saved to `Crops/Processed/masks/`.

### Step 4 – Check masks and analyze (`04_masks_and_distance_analysis.ijm`, interactive)

1. Run the macro and select `raw_data/Crops/Processed/`.
2. For each ratio image the nucleus outline is shown. If it is correct press **OK**, otherwise draw a new one
   with the freehand tool and then press OK.
3. The same for the cell outline.

The macro then computes the geodesic distance from the nucleus within the cell (MorphoLibJ) and saves, in
`Crops/Processed/`, `*_distMap.tif` and `*_result.csv`. The `*_result.csv` stores one row per pixel inside the cell with `X`, `Y`,
`Value` (ratio) and `Distance` (from the nucleus).

## Cellpose models

- `models/CP_20250425_cells_bin3_sumJN` for cells
- `models/CP_20250425_nuc_bin3_sumJN02` for nuclei 

Training images are channel-1 sum projections, binned 3 × 3, and contrast enhanced (CLAHE), with manually corrected masks
(`*_masks.tif`) from the Cellpose GUI. Models were trained with Cellpose 3 for 100 (cells) and 200 (nuclei) epochs.
Base model = 'cyto3', other training parameters set as default (learning rate = 0.1, weight decay = 0.0001, stochastic gradient descent (SGD)).
