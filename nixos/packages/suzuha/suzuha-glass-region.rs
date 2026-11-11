use super::{Blob, CONNECTION, EDGE_OFFSET, Placement};
use amane::InputArea;

// Match liquid.wgsl's signed distance, in surface coordinates. This is also
// the blur boundary: transparent space between panels must stay untouched.
fn distance(x: f32, y: f32, blobs: &[Blob], placement: &Placement) -> f32 {
    let sx = x + placement.x;
    let sy = y + placement.y;
    let mut distance = sx
        .min(placement.screen_width - sx)
        .min(sy.min(placement.screen_height - sy))
        + EDGE_OFFSET;
    for blob in blobs {
        let hx = blob.width * 0.5;
        let hy = blob.height * 0.5;
        let radius = blob.radius.min(hx.min(hy));
        let dx = (sx - blob.x - hx).abs() - hx + radius;
        let dy = (sy - blob.y - hy).abs() - hy + radius;
        let shape = dx.max(dy).min(0.0) + dx.max(0.0).hypot(dy.max(0.0)) - radius;
        let blend = (0.5 + 0.5 * (shape - distance) / CONNECTION).clamp(0.0, 1.0);
        distance = shape + (distance - shape) * blend - CONNECTION * blend * (1.0 - blend);
    }
    distance
}

pub fn blur_region(
    blobs: &[Blob],
    placement: &Placement,
    width: f32,
    height: f32,
) -> Vec<InputArea> {
    let mut regions: Vec<InputArea> = Vec::new();
    if blobs.is_empty() {
        return regions;
    }
    let width = width.ceil().max(0.0) as i32;
    let height = height.ceil().max(0.0) as i32;
    let mut previous: Vec<(i32, i32, usize)> = Vec::new();
    for y in 0..height {
        let mut row = Vec::new();
        let mut x = 0;
        let mut start = None;
        while x < width {
            let d = distance(x as f32 + 0.5, y as f32 + 0.5, blobs, placement);
            if d < 0.0 {
                start.get_or_insert(x);
            } else if let Some(left) = start.take() {
                row.push((left, x));
            }
            // A signed distance cannot cross an edge in less than abs(d).
            // March across flat interiors instead of visiting every pixel.
            x = (x + (d.abs().floor() as i32).max(1)).min(width);
        }
        if let Some(left) = start {
            row.push((left, width));
        }
        let mut current = Vec::new();
        for (left, right) in row {
            let index = if let Some((_, _, index)) =
                previous.iter().find(|(l, r, _)| *l == left && *r == right)
            {
                regions[*index].height += 1;
                *index
            } else {
                regions.push(InputArea {
                    x: left,
                    y,
                    width: right - left,
                    height: 1,
                });
                regions.len() - 1
            };
            current.push((left, right, index));
        }
        previous = current;
    }
    regions
}

#[cfg(test)]
mod tests {
    use super::*;
    fn covered(regions: &[InputArea], x: i32, y: i32) -> bool {
        regions
            .iter()
            .any(|r| x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height)
    }
    #[test]
    fn separated_panels_leave_gap_and_rounded_corners_clear() {
        let placement = Placement {
            x: 100.0,
            y: 80.0,
            screen_width: 1000.0,
            screen_height: 800.0,
        };
        let blobs = vec![
            Blob::new(110.0, 90.0, 100.0, 100.0).radius(20.0),
            Blob::new(310.0, 90.0, 100.0, 100.0).radius(20.0),
        ];
        let regions = blur_region(&blobs, &placement, 330.0, 130.0);
        assert!(covered(&regions, 60, 60));
        assert!(covered(&regions, 260, 60));
        assert!(!covered(&regions, 160, 60));
        assert!(!covered(&regions, 10, 10));
        assert!(!covered(&regions, 60, 120));
        assert!(blur_region(&[], &placement, 330.0, 130.0).is_empty());
    }
    #[test]
    fn marching_matches_every_pixel_through_merging_and_moving_panels() {
        for shift in [0.0, 0.4, 18.5, 41.0] {
            let placement = Placement {
                x: 4.0,
                y: 2.0,
                screen_width: 240.0,
                screen_height: 180.0,
            };
            let blobs = vec![
                Blob::new(9.0, -shift, 80.0, 85.0).radius(20.0),
                Blob::new(102.0 - shift, 20.0, 70.0, 80.0).radius(16.0),
            ];
            let regions = blur_region(&blobs, &placement, 190.0, 120.0);
            for y in 0..120 {
                for x in 0..190 {
                    assert_eq!(
                        covered(&regions, x, y),
                        distance(x as f32 + 0.5, y as f32 + 0.5, &blobs, &placement) < 0.0,
                        "at {x},{y} shift {shift}"
                    );
                }
            }
        }
    }
}
