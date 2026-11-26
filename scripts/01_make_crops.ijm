// =============================================================================
// Step 1 - Interactive cropping of cells from raw .nd2 Z-stacks
//
// Input : folder with raw .nd2 files (e.g. raw_data/)
// Output: <input>/Crops/<name>_x<X>_y<Y>_w<W>_h<H>.tif
//         (full Z-stack, all channels) 
//         crop box is stored in the file name
//
// For each .nd2 file a max projection is shown. Draw rectangles around the
// cells of interest and add each one to the ROI Manager (Ctrl+T), then press OK.
// Leave at least ~100 px around each cell. No ROI = image is skipped.
// =============================================================================

inputFolder = getDirectory("Select folder with raw .nd2 files");
files = getFileList(inputFolder);
outputFolder = inputFolder + "Crops" + File.separator;
if (!File.exists(outputFolder))
    File.makeDirectory(outputFolder);

for (f = 0; f < files.length; f++) {
    if (endsWith(files[f], ".nd2")) {
        filePath = inputFolder + files[f];
        run("Bio-Formats Importer", "open=[" + filePath + "] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
        sampleImage = getTitle();
        fileName = File.nameWithoutExtension;
        pickROIs(sampleImage);
    }
}
print("All files have been processed!");


// Show a max projection, let the user pick ROIs and save each one as a crop
function pickROIs(sampleImage) {
    roiManager("reset");
    selectWindow(sampleImage);
    run("Z Project...", "projection=[Max Intensity]");
    rename("temp1");
    run("Enhance Contrast", "saturated=0.3");
    run("Fire");

    setTool("rectangle");
    waitForUser("Select rectangular ROIs around cells to analyse.\n"
        + "Add each selection to the ROI Manager with Ctrl+T.\n"
        + "Include at least ~100 pixels around each cell.\n"
        + "Select all = keep the whole image; select nothing = skip the image.\n"
        + "When done, press OK.");

    n_rois = roiManager("count");
    print(sampleImage + " --- selected ROIs: " + n_rois);
    for (i = 0; i < n_rois; i++) {
        selectImage(sampleImage);
        roiManager("Select", i);
        Roi.getBounds(x, y, width, height);
        run("Duplicate...", "duplicate");
        saveAs("Tiff", outputFolder + fileName + "_x" + x + "_y" + y + "_w" + width + "_h" + height + ".tif");
    }
    close("*");
}
