use smithay_client_toolkit::reexports::protocols::ext::background_effect::v1::client::{
    ext_background_effect_manager_v1::{self, ExtBackgroundEffectManagerV1},
    ext_background_effect_surface_v1::{self, ExtBackgroundEffectSurfaceV1},
};
use wayland_client::{Connection, Dispatch, QueueHandle};

use super::{WaylandState, surface::OpenWindow, update::scaled_region};
use crate::{InputArea, LayerWindow};

pub type Manager = ExtBackgroundEffectManagerV1;

// Destroy the extension before its wl_surface, including when a monitor disappears.
pub struct Effect {
    surface: ExtBackgroundEffectSurfaceV1,
    region: Vec<InputArea>,
}

impl Drop for Effect {
    fn drop(&mut self) {
        self.surface.destroy();
    }
}

impl OpenWindow {
    pub fn update_blur_region(&mut self, window: &LayerWindow) {
        let Some(areas) = &window.blur_region else {
            self.background_effect = None;
            return;
        };
        let Some(manager) = &self.blur_manager else {
            return;
        };
        let areas: Vec<_> = areas
            .iter()
            .map(|area| scaled_region(*area, self.scale_factor))
            .collect();
        if let Some(effect) = &self.background_effect {
            if effect.region == areas {
                return;
            }
        }
        let effect = self.background_effect.get_or_insert_with(|| Effect {
            surface: manager.get_background_effect(self.role.wl_surface(), &self.qh, ()),
            region: Vec::new(),
        });
        let region = self.compositor.create_region(&self.qh, ());
        for area in &areas {
            if area.width > 0 && area.height > 0 {
                region.add(area.x, area.y, area.width, area.height);
            }
        }
        effect.surface.set_blur_region(Some(&region));
        effect.region = areas;
        region.destroy();
    }
}

impl Dispatch<Manager, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &Manager,
        _: ext_background_effect_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ExtBackgroundEffectSurfaceV1, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &ExtBackgroundEffectSurfaceV1,
        _: ext_background_effect_surface_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn glass_shader_is_valid_wgsl() {
        use vello::wgpu::naga::{
            front::wgsl,
            valid::{Capabilities, ValidationFlags, Validator},
        };
        let source = format!(
            "@group(0) @binding(0) var<uniform> size: vec2<f32>;\n\
             @group(0) @binding(3) var<uniform> values: array<vec4<f32>, 16>;\n{}",
            include_str!("@liquidShader@")
        );
        let module = wgsl::parse_str(&source).expect("glass shader must parse");
        Validator::new(ValidationFlags::all(), Capabilities::all())
            .validate(&module)
            .expect("glass shader must validate");
    }
}
