// =============================================================================
// Step 2 - Batch processing of crops: ratio images + images for segmentation
//
// Input : folder with cropped .tif stacks from step 1 (e.g. raw_data/Crops/)
//
// Output: <input>/Processed/<name>_ratio.tif   32-bit ratio (C1-C2)/(C1+C2)
//         <input>/Processed/<name>_report.jpg  overview with calibration/scale bar
//         <input>/Temporary/<name>_sum_bin_clahe_c1.tif  C1 for Cellpose (step 3)
//
// Per channel: median filter (r=1) -> SUM projection -> 3x3 average binning.
// Modified from the original ratio-image macro by Jaromir Novak.
// =============================================================================

inputFolder = getDirectory("Select folder with cropped images");
files = getFileList(inputFolder);
outputFolder = inputFolder + "Processed" + File.separator;
segmentationFolder = inputFolder + "Temporary" + File.separator;
if (!File.exists(outputFolder))
    File.makeDirectory(outputFolder);
if (!File.exists(segmentationFolder))
    File.makeDirectory(segmentationFolder);

setBatchMode("hide");
for (f = 0; f < files.length; f++) {
    if (endsWith(files[f], ".tif")) {
        open(inputFolder + files[f]);
        sampleImage = getTitle();
        fileName = File.nameWithoutExtension;
        processSampleForSegmentation(sampleImage);
        processFile(sampleImage, "Corrected_Image");
        close("*");
    }
}
print("Processing complete!");


// Channel 1 projections (binned + CLAHE) used as Cellpose input
function processSampleForSegmentation(sampleImage) {
    selectWindow(sampleImage);
    run("Duplicate...", "title=Sample_Duplicate_c1 duplicate channels=1");
    run("Median...", "radius=1 stack");

    selectWindow("Sample_Duplicate_c1");
    run("Z Project...", "projection=[Sum Slices]");
    run("Bin...", "x=3 y=3 bin=Average");
    run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
    saveAs("Tiff", segmentationFolder + fileName + "_sum_bin_clahe_c1.tif");

    close("Sample_Duplicate_c1");
    close(fileName + "_sum_bin_clahe_c1.tif");
}

// Median filter, SUM projection and binning of one channel -> "<resultTitle>_<channel>"
function processSample(sampleImage, resultTitle, channel) {
    selectWindow(sampleImage);
    run("Duplicate...", "title=Sample_Duplicate_" + channel + " duplicate channels=" + channel);
    run("Median...", "radius=1 stack");
    selectWindow("Sample_Duplicate_" + channel);
    run("Z Project...", "projection=[Sum Slices]");
    run("Bin...", "x=3 y=3 bin=Average");
    rename(resultTitle + "_" + channel);
}

// Ratio image (C1-C2)/(C1+C2) and overview report
function processFile(sampleImage, resultTitle) {
    processSample(sampleImage, resultTitle, 1);
    processSample(sampleImage, resultTitle, 2);

    // Stack/unstack only to carry the (binned) pixel calibration over to both channels
    getPixelSize(unit, pixelWidth, pixelHeight);
    run("Images to Stack", "title=Corrected use");
    run("Set Scale...", "distance=1 known=" + pixelWidth + " unit=" + unit);
    run("Stack to Images");

    imageCalculator("Subtract create 32-bit", "Corrected_Image_1", "Corrected_Image_2");
    rename("Subtracted_Image");
    imageCalculator("Add create 32-bit", "Corrected_Image_1", "Corrected_Image_2");
    rename("Summed_Image");
    imageCalculator("Divide create 32-bit", "Subtracted_Image", "Summed_Image");
    rename("Result_Image");

    selectImage("Result_Image");
    run("Duplicate...", " ");
    saveAs("Tiff", outputFolder + fileName + "_ratio.tif");

    // Overview image (ratio in [-1, 1], "phase" LUT)
    selectImage("Result_Image");
    run("phase");
    setMinAndMax(-1, 1);
    run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=1 font=3 zoom=1 overlay");
    run("Scale Bar...", "width=25 height=50 thickness=5 font=24 bold overlay");
    saveAs("Jpeg", outputFolder + fileName + "_report.jpg");
}
