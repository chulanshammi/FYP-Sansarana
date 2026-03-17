import nbformat as nbf

# Read the notebook
with open('d:/Sansarana/Interim_Demo.ipynb', 'r', encoding='utf-8') as f:
    nb = nbf.read(f, as_version=4)

# Keep only up to cell 6
valid_cells = []
for idx, cell in enumerate(nb.cells):
    if idx <= 6:
        valid_cells.append(cell)

nb.cells = valid_cells

md_process = nbf.v4.new_markdown_cell("### Segmenting Request\nAssuming the point is exactly in the middle of the frame.")
code_process = nbf.v4.new_code_cell("""predictor.set_image(image)

h, w, _ = image.shape
input_point = np.array([[w // 2, h // 2]])
input_label = np.array([1]) # Positive Prompt

masks, scores, logits = predictor.predict(
    point_coords=input_point,
    point_labels=input_label,
    multimask_output=True,
)

# Choose the mask with the highest score
best_mask = masks[np.argmax(scores)]""")

# Now replace the interactive stuff with a simple process
md_blur = nbf.v4.new_markdown_cell("### Apply Mask and Blur Background")
code_blur = nbf.v4.new_code_cell("""import cv2
from PIL import Image

# Save the finalized mask explicitly
if best_mask is not None:
    mask_to_save = (best_mask * 255).astype(np.uint8)
    Image.fromarray(mask_to_save).save("seated_buddha_manual_mask.png")
    print("Mask saved as seated_buddha_manual_mask.png")

    # Composite logic: Blurred background, unblurred segmented region
    mask = best_mask.astype(np.uint8)[:, :, np.newaxis]
    blurred_bg = cv2.GaussianBlur(image, (51, 51), 0)
    final_image = np.where(mask == 1, image, blurred_bg)

    # Convert back to inline for this plot (to avoid widget interaction in next cells)
    %matplotlib inline
    plt.figure(figsize=(10, 10))
    plt.imshow(final_image)
    plt.axis('off')
    plt.title("Blurred Background Segmentation", fontsize=18)
    plt.show()
else:
    print("No mask was generated.")""")

nb.cells.extend([md_process, code_process, md_blur, code_blur])

with open('d:/Sansarana/Interim_Demo.ipynb', 'w', encoding='utf-8') as f:
    nbf.write(nb, f)
