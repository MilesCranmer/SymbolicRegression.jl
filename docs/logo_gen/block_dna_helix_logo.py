import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Polygon
from matplotlib.path import Path
import matplotlib.patches as mpatches
import matplotlib.colors as mcolors

# Set font with math rendering
plt.rcParams['font.family'] = 'serif'
plt.rcParams['mathtext.fontset'] = 'stix'  # STIX fonts for better math rendering

# Julia language colors
# Julia colors - muted but elegant and readable
julia_colors = {
    'red': '#A54A42',
    'green': '#4A7E3A',
    'blue': '#4F5FAE',
    'purple': '#7D5F8B'
}

# Font size for mathematical symbols
FONT_SIZE = 22

def create_ribbon_path(x_center, y_center, dx, dy, width):
    """Create ribbon edges by offsetting the center curve"""
    # Calculate perpendicular direction
    length = np.sqrt(dx**2 + dy**2)
    if length == 0:
        perp_x, perp_y = 0, 1
    else:
        perp_x = -dy / length
        perp_y = dx / length

    # Create ribbon edges
    half_width = width / 2
    x_left = x_center + perp_x * half_width
    y_left = y_center + perp_y * half_width
    x_right = x_center - perp_x * half_width
    y_right = y_center - perp_y * half_width

    return x_left, y_left, x_right, y_right

def draw_smooth_ribbon_segment(ax, x_coords, y_coords, start_idx, end_idx, color, width, zorder_base=5):
    """Draw a smooth ribbon segment"""
    if end_idx >= len(x_coords) or start_idx >= end_idx:
        return

    # Extract segment
    x_seg = x_coords[start_idx:end_idx+1]
    y_seg = y_coords[start_idx:end_idx+1]

    if len(x_seg) < 2:
        return

    # Calculate derivatives for perpendicular direction
    x_left_all = []
    y_left_all = []
    x_right_all = []
    y_right_all = []

    for i in range(len(x_seg)):
        if i == 0:
            dx = x_seg[1] - x_seg[0]
            dy = y_seg[1] - y_seg[0]
        elif i == len(x_seg) - 1:
            dx = x_seg[-1] - x_seg[-2]
            dy = y_seg[-1] - y_seg[-2]
        else:
            dx = x_seg[i+1] - x_seg[i-1]
            dy = y_seg[i+1] - y_seg[i-1]

        x_left, y_left, x_right, y_right = create_ribbon_path(x_seg[i], y_seg[i], dx, dy, width)
        x_left_all.append(x_left)
        y_left_all.append(y_left)
        x_right_all.append(x_right)
        y_right_all.append(y_right)

    # Create ribbon using fill_between equivalent
    x_ribbon = np.concatenate([x_left_all, x_right_all[::-1]])
    y_ribbon = np.concatenate([y_left_all, y_right_all[::-1]])

    # Draw solid ribbon
    ribbon = Polygon(list(zip(x_ribbon, y_ribbon)),
                    facecolor=color, edgecolor='none', zorder=zorder_base)
    ax.add_patch(ribbon)

    return x_left_all, y_left_all, x_right_all, y_right_all

def create_smooth_dna_helix():
    fig, ax = plt.subplots(1, 1, figsize=(8, 6))
    ax.set_xlim(1.2, -1.2)
    ax.set_ylim(-1.98, 1.98)
    ax.set_aspect('equal')
    ax.axis('off')
    ax.set_facecolor('white')

    # Parameters for smooth DNA helix
    n_segments = 8  # Number of segments along each strand
    # Create helix like classic DNA structure - exactly 1 full rotation
    total_rotations = 1.0  # Exactly one complete rotation
    total_param_length = total_rotations * 2 * np.pi
    half_param_length = total_param_length / 2

    t = np.linspace(-half_param_length, half_param_length, 600)  # More points for smoother curve
    radius = 0.8  # Good radius for classic DNA look

    # Create helix coordinates with classic DNA proportions - perfect for 1 rotation
    x1 = radius * np.cos(t)
    y1 = t / np.pi * 1.8  # Perfect height for classic DNA with exactly 1 rotation
    x2 = radius * np.cos(t + np.pi)
    y2 = t / np.pi * 1.8

    # Calculate z-coordinates for 3D depth effect
    z1 = radius * np.sin(t)
    z2 = radius * np.sin(t + np.pi)

    # Simple mathematical symbol base pairs (like DNA A-T, G-C pairing)
    symbol_pairs = [
        (r'$\exp$', r'$\log$'),  # exponential functions
        (r'$+$', r'$-$'),     # add and subtract
        (r'$x$', r'$y$'),     # variables
        (r'$\pi$', r'$e$'),     # mathematical constants
        (r'$\times$', r'$\div$'),     # multiply and divide
        (r'$\sin$', r'$\cos$'),  # trigonometric functions
        (r'$z$', r'$x$'),     # more variables
        (r'$\max$', r'$\min$'),  # optimization functions
        (r'$\vee$', r'$\wedge$'),     # logical or and and
        (r'$y$', r'$z$'),     # variables
    ]

    # Flatten to individual symbols for color assignment
    all_symbols = []
    for pair in symbol_pairs:
        all_symbols.extend(pair)

    # Julia colors for the 4 different "bases"
    base_colors = [julia_colors['red'], julia_colors['green'], julia_colors['blue'], julia_colors['purple']]

    # Calculate arc lengths for equal-sized segments
    def calculate_arc_length(x_coords, y_coords):
        """Calculate cumulative arc length along curve"""
        dx = np.diff(x_coords)
        dy = np.diff(y_coords)
        ds = np.sqrt(dx**2 + dy**2)
        return np.concatenate([[0], np.cumsum(ds)])

    # Get arc lengths for both strands
    arc1 = calculate_arc_length(x1, y1)
    arc2 = calculate_arc_length(x2, y2)

    # Create equal arc length segments
    ribbon_width = 0.42
    # n_segments already defined above

    # Calculate segment boundaries based on arc length
    total_arc1 = arc1[-1]
    total_arc2 = arc2[-1]

    def find_index_for_arc_length(arc_array, target_length):
        """Find index corresponding to target arc length"""
        return np.searchsorted(arc_array, target_length)

    # Prepare segment info for proper layered drawing
    segment_info = []

    for seg in range(n_segments):
        # Calculate arc length positions for this segment
        start_arc = (seg / n_segments) * min(total_arc1, total_arc2)
        end_arc = ((seg + 1) / n_segments) * min(total_arc1, total_arc2)

        # Find corresponding indices
        start_idx1 = find_index_for_arc_length(arc1, start_arc)
        end_idx1 = find_index_for_arc_length(arc1, end_arc)
        start_idx2 = find_index_for_arc_length(arc2, start_arc)
        end_idx2 = find_index_for_arc_length(arc2, end_arc)

        # Ensure valid indices
        start_idx1 = max(0, min(start_idx1, len(x1) - 2))
        end_idx1 = max(start_idx1 + 1, min(end_idx1 + 2, len(x1) - 1))
        start_idx2 = max(0, min(start_idx2, len(x2) - 2))
        end_idx2 = max(start_idx2 + 1, min(end_idx2 + 2, len(x2) - 1))

        # Choose base pair sequentially cycling through pairs
        pair_idx = seg % len(symbol_pairs)
        symbol1, symbol2 = symbol_pairs[pair_idx]

        # Assign colors sequentially (1-2-3-4 cycle for each strand)
        color1 = base_colors[seg % len(base_colors)]
        color2 = base_colors[(seg + 2) % len(base_colors)]  # Offset colors for visual variety

        # Calculate average z for layering (determine which strand is in front)
        avg_z1 = np.mean(z1[start_idx1:end_idx1])
        avg_z2 = np.mean(z2[start_idx2:end_idx2])

        # Calculate center positions for symbols
        center_arc = ((seg + 0.5) / n_segments) * min(total_arc1, total_arc2)
        center_idx1 = find_index_for_arc_length(arc1, center_arc)
        center_idx2 = find_index_for_arc_length(arc2, center_arc)
        center_idx1 = max(0, min(center_idx1, len(x1) - 1))
        center_idx2 = max(0, min(center_idx2, len(x2) - 1))

        # Store all info for layered drawing
        segment_info.append({
            'seg': seg,
            'start_idx1': start_idx1, 'end_idx1': end_idx1,
            'start_idx2': start_idx2, 'end_idx2': end_idx2,
            'center_idx1': center_idx1, 'center_idx2': center_idx2,
            'symbol1': symbol1, 'symbol2': symbol2,
            'color1': color1, 'color2': color2,
            'avg_z1': avg_z1, 'avg_z2': avg_z2
        })

    # Draw in proper order: back strand → back text → front strand → front text
    for info in segment_info:
        # Determine which strand is in back (lower z) and which is in front (higher z)
        if info['avg_z1'] < info['avg_z2']:
            # Strand 1 is in back, strand 2 is in front
            back_strand = 1
            front_strand = 2
        else:
            # Strand 2 is in back, strand 1 is in front
            back_strand = 2
            front_strand = 1

        # Draw back strand (zorder 1)
        if back_strand == 1:
            draw_smooth_ribbon_segment(ax, x1, y1, info['start_idx1'], info['end_idx1'],
                                     info['color1'], ribbon_width, zorder_base=1)
        else:
            draw_smooth_ribbon_segment(ax, x2, y2, info['start_idx2'], info['end_idx2'],
                                     info['color2'], ribbon_width, zorder_base=1)

        # Draw back strand text (zorder 2)
        if back_strand == 1:
            # Calculate rotation for strand 1 text
            if info['center_idx1'] < len(t) - 5:
                dx = x1[info['center_idx1'] + 5] - x1[info['center_idx1']]
                dy = y1[info['center_idx1'] + 5] - y1[info['center_idx1']]
                angle = np.arctan2(dy, dx)
            else:
                angle = 0
            rotation = np.degrees(angle) % 360
            if rotation > 180: rotation -= 360
            if rotation > 90: rotation -= 180
            elif rotation < -90: rotation += 180
            rotation = -rotation  # Flip rotation for x-axis flip

            ax.text(x1[info['center_idx1']], y1[info['center_idx1']], info['symbol1'],
                   fontsize=FONT_SIZE, ha='center', va='center', color='white', weight='bold',
                   rotation=rotation, zorder=2)
        else:
            # Calculate rotation for strand 2 text
            if info['center_idx2'] < len(t) - 5:
                dx = x2[info['center_idx2'] + 5] - x2[info['center_idx2']]
                dy = y2[info['center_idx2'] + 5] - y2[info['center_idx2']]
                angle = np.arctan2(dy, dx)
            else:
                angle = 0
            rotation = np.degrees(angle) % 360
            if rotation > 180: rotation -= 360
            if rotation > 90: rotation -= 180
            elif rotation < -90: rotation += 180
            rotation = -rotation  # Flip rotation for x-axis flip

            ax.text(x2[info['center_idx2']], y2[info['center_idx2']], info['symbol2'],
                   fontsize=FONT_SIZE, ha='center', va='center', color='white', weight='bold',
                   rotation=rotation, zorder=2)

        # Draw front strand (zorder 3)
        if front_strand == 1:
            draw_smooth_ribbon_segment(ax, x1, y1, info['start_idx1'], info['end_idx1'],
                                     info['color1'], ribbon_width, zorder_base=3)
        else:
            draw_smooth_ribbon_segment(ax, x2, y2, info['start_idx2'], info['end_idx2'],
                                     info['color2'], ribbon_width, zorder_base=3)

        # Draw front strand text (zorder 4)
        if front_strand == 1:
            # Calculate rotation for strand 1 text
            if info['center_idx1'] < len(t) - 5:
                dx = x1[info['center_idx1'] + 5] - x1[info['center_idx1']]
                dy = y1[info['center_idx1'] + 5] - y1[info['center_idx1']]
                angle = np.arctan2(dy, dx)
            else:
                angle = 0
            rotation = np.degrees(angle) % 360
            if rotation > 180: rotation -= 360
            if rotation > 90: rotation -= 180
            elif rotation < -90: rotation += 180
            rotation = -rotation  # Flip rotation for x-axis flip

            ax.text(x1[info['center_idx1']], y1[info['center_idx1']], info['symbol1'],
                   fontsize=FONT_SIZE, ha='center', va='center', color='white', weight='bold',
                   rotation=rotation, zorder=4)
        else:
            # Calculate rotation for strand 2 text
            if info['center_idx2'] < len(t) - 5:
                dx = x2[info['center_idx2'] + 5] - x2[info['center_idx2']]
                dy = y2[info['center_idx2'] + 5] - y2[info['center_idx2']]
                angle = np.arctan2(dy, dx)
            else:
                angle = 0
            rotation = np.degrees(angle) % 360
            if rotation > 180: rotation -= 360
            if rotation > 90: rotation -= 180
            elif rotation < -90: rotation += 180
            rotation = -rotation  # Flip rotation for x-axis flip

            ax.text(x2[info['center_idx2']], y2[info['center_idx2']], info['symbol2'],
                   fontsize=FONT_SIZE, ha='center', va='center', color='white', weight='bold',
                   rotation=rotation, zorder=4)




    plt.tight_layout()
    return fig

# Create and save the illustration
if __name__ == "__main__":
    fig = create_smooth_dna_helix()
    plt.savefig('block_dna_helix_logo.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.savefig('block_dna_helix_logo.svg', bbox_inches='tight',
                facecolor='white', edgecolor='none')
    print("Smooth DNA helix logo created successfully!")
