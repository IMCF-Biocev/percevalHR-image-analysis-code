// =============================================================================
// Step 4 - Interactive mask check + ratio vs. distance-from-nucleus analysis
//
// Input : <Processed>/<name>_ratio.tif              (step 2)
//         <Processed>/masks/<name>_nuc.tif, _cell.tif (step 3, optional)
// Output: <Processed>/<name>_distMap.tif   geodesic distance map from the nucleus
//         <Processed>/<name>_result.csv    per-pixel X, Y, ratio (Value) and Distance
//
// For each ratio image the nucleus and cell masks are loaded (only the object
// closest to the image centre is kept) and shown for confirmation - adjust or
// redraw them with the freehand tool and press OK. Without masks, draw them.
// Requires MorphoLibJ (IJPB-plugins update site).
//
// Modified from the original macro by Jaromir Novak.
// =============================================================================

inputFolder = getDirectory("Select folder with ratio images (Processed)");
inputMaskDir = inputFolder + "masks";
files = getFileList(inputFolder);

for (f = 0; f < files.length; f++) {
    if (endsWith(files[f], "ratio.tif")) {
        nuc_mask_path = inputMaskDir + File.separator + replace(files[f], "ratio", "nuc");
        cell_mask_path = inputMaskDir + File.separator + replace(files[f], "ratio", "cell");
        open(inputFolder + files[f]);
        run("Enhance Contrast", "saturated=0.35");
        title = getTitle();
        fileName = File.nameWithoutExtension;

        createMask(nuc_mask_path, "nuclei");
        createMask(cell_mask_path, "cell");
        distanceMap();
        close("*");
    }
}
print("Analysis finished!");


// Keep only the label closest to the image centre, as binary mask named mName
function keepMiddleLabel(labelImage, mName) {
    selectImage(labelImage);
    image_center_x = getWidth() / 2;
    image_center_y = getHeight() / 2;
    toScaled(image_center_x, image_center_y);

    run("Analyze Regions", "area centroid average_thickness");
    l = Table.size;
    minDist = -1;
    minLabel = "";
    for (i = 0; i < l; i++) {
        dx = Table.get("Centroid.X", i) - image_center_x;
        dy = Table.get("Centroid.Y", i) - image_center_y;
        distance = sqrt(dx * dx + dy * dy);
        if (minDist < 0 || distance < minDist) {
            minDist = distance;
            minLabel = Table.getString("Label", i);
        }
    }

    run("Select Label(s)", "label(s)=" + minLabel);
    rename(mName);
    setThreshold(1, 255);
    run("Convert to Mask");
}

// Load a mask (if present) for user check/redraw; result is "final_<type>"
function createMask(path, type) {
    roiManager("reset");
    if (File.exists(path)) {
        open(path);
        keepMiddleLabel(getTitle(), type);
        selectImage(type);
        run("Create Selection");
        roiManager("Add");
        selectImage(title);
        roiManager("Select", 0);
        setTool("freehand");
        waitForUser("Check if " + type + " is OK, otherwise redraw it");
    } else {
        selectImage(title);
        setTool("freehand");
        waitForUser("Draw " + type);
    }
    run("Create Mask");
    rename("final_" + type);
}

// Geodesic distance from the nucleus within the cell; export per-pixel ratio + distance
function distanceMap() {
    roiManager("reset");
    selectImage("final_cell");
    run("Create Selection");
    roiManager("add");

    run("Geodesic Distance Map", "marker=final_nuclei mask=final_cell distances=[Chessknight (5,7,11)] output=[32 bits] normalize");
    run("Enhance Contrast", "saturated=0.35");
    selectImage("final_cell-geoddist");
    saveAs("Tiff", inputFolder + fileName + "_distMap.tif");

    // Same ROI on both images -> identical pixel order in both tables
    roiManager("Select", 0);
    table_d_path = inputFolder + "cell-geoddist.csv";
    run("Save XY Coordinates...", "save=[" + table_d_path + "]");

    selectImage(title);
    roiManager("Select", 0);
    table_r_path = inputFolder + "cell-ratio.csv";
    run("Save XY Coordinates...", "save=[" + table_r_path + "]");

    mergeTables(table_r_path, table_d_path);
}

// Append the distance column to the ratio table and save as <name>_result.csv
function mergeTables(table_r_path, table_d_path) {
    Table.open(table_d_path);
    table2 = Table.title;
    dist_arr = Table.getColumn("Value");

    Table.open(table_r_path);
    table1 = Table.title;
    Table.setColumn("Distance", dist_arr);

    selectWindow(table1);
    saveAs("Results", inputFolder + fileName + "_result.csv");
    close(table1);
    close(table2);
    print("Merged result table saved --- " + fileName + "_result.csv");
}
