import nbformat as nbf

# Read the notebook
with open('d:/Sansarana/Interim_Demo.ipynb', 'r', encoding='utf-8') as f:
    nb = nbf.read(f, as_version=4)

# Keep only cells 0-7, assuming cell 8 and 9 were corrupted or unnecessary
valid_cells = []
for idx, cell in enumerate(nb.cells):
    if idx <= 6:
        valid_cells.append(cell)

nb.cells = valid_cells

# Interactive cell
md_interactive = nbf.v4.new_markdown_cell("### Interactive Segmentation\nLeft-click to add positive points, right-click to add negative points. The mask will update automatically. Run this cell to start.")
code_interactive = nbf.v4.new_code_cell("""%matplotlib notebook
import matplotlib.pyplot as plt
import numpy as np

# Clear previous figure if any
plt.close('all')

# Center point roughly assuming it's useful to start with
h, w, _ = image.shape
input_points = [[w // 2, h // 2]]
input_labels = [1]

best_mask = None

fig, ax = plt.subplots(figsize=(10, 10))
ax.imshow(image)
ax.set_title("Interactive Segmentation: Left Click (+), Right Click (-)\\nClose window when done.")
plt.axis('off')

def show_mask(mask, ax):
    color = np.array([30/255, 144/255, 255/255, 0.6])
    h, w = mask.shape[-2:]
    mask_image = mask.reshape(h, w, 1) * color.reshape(1, 1, -1)
    ax.imshow(mask_image)

def show_points(coords, labels, ax, marker_size=375):
    pos_points = coords[labels==1]
    neg_points = coords[labels==0]
    if len(pos_points) > 0:
        ax.scatter(pos_points[:, 0], pos_points[:, 1], color='green', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)
    if len(neg_points) > 0:
        ax.scatter(neg_points[:, 0], neg_points[:, 1], color='red', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)

def onclick(event):
    global best_mask
    if event.xdata is None or event.ydata is None:
        return
    x, y = int(event.xdata), int(event.ydata)
    
    if event.button == 1:
        input_points.append([x, y])
        input_labels.append(1)
    elif event.button == 3:
        input_points.append([x, y])
        input_labels.append(0)
    else:
        return
        
    pts = np.array(input_points)
    lbls = np.array(input_labels)
    
    masks, scores, logits = predictor.predict(
        point_coords=pts,
        point_labels=lbls,
        multimask_output=True,
    )
    best_mask = masks[np.argmax(scores)]
    
    ax.clear()
    ax.imshow(image)
    show_mask(best_mask, ax)
    show_points(pts, lbls, ax)
    ax.set_title("Interactive Segmentation: Left Click (+), Right Click (-)\\nClose window when done.")
    plt.axis('off')
    fig.canvas.draw()

# Initial prediction
pts = np.array(input_points)
lbls = np.array(input_labels)
masks, scores, logits = predictor.predict(
    point_coords=pts,
    point_labels=lbls,
    multimask_output=True,
)
best_mask = masks[np.argmax(scores)]
show_mask(best_mask, ax)
show_points(pts, lbls, ax)

cid = fig.canvas.mpl_connect('button_press_event', onclick)
plt.show()""")

md_blur = nbf.v4.new_markdown_cell("### Save Mask and Visualization\nApply the blurred background logic using the generated `best_mask`.")
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
    print("No mask was generated. Please run the interactive cell above.")""")

nb.cells.extend([md_interactive, code_interactive, md_blur, code_blur])

with open('d:/Sansarana/Interim_Demo.ipynb', 'w', encoding='utf-8') as f:
    nbf.write(nb, f)
