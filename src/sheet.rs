#[derive(Debug, serde::Deserialize)]
pub struct SheetRect {
    pub x: i16,
    pub y: i16,
    pub w: i16,
    pub h: i16,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Cell {
    pub frame: SheetRect,
    pub sprite_source_size: SheetRect,
}

#[derive(Debug, serde::Deserialize)]
pub struct Sheet {
    pub frames: std::collections::HashMap<String, Cell>,
}
