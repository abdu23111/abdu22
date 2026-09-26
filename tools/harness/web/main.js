// Renders one shot exported by tools/harness/render.py.
import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const params = new URLSearchParams(location.search);
const shotName = params.get("shot");
const W = Number(params.get("w") || 1280);
const H = Number(params.get("h") || 720);
const MAX_LIGHTS = Number(params.get("lights") || 48);

function srgb(c, k = 1) {
  const col = new THREE.Color();
  col.setRGB(c[0], c[1], c[2], THREE.SRGBColorSpace);
  if (k !== 1) col.multiplyScalar(k);
  return col;
}

function decode(b64, Type) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Type(bytes.buffer);
}

// Unit geometries, scaled per part.
const GEO = {
  box: new THREE.BoxGeometry(1, 1, 1),
  sphere: new THREE.SphereGeometry(0.5, 18, 12),
  cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 18).rotateZ(Math.PI / 2), // Roblox cylinders run along X
  meshCyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 18), // SpecialMesh cylinders run along Y
  wedge: (() => {
    // Roblox WedgePart: full bottom and back (+Z) faces, slope rising from the front-bottom edge.
    const g = new THREE.BufferGeometry();
    const v = [
      [-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5, 0.5], [-0.5, -0.5, 0.5],
      [-0.5, 0.5, 0.5], [0.5, 0.5, 0.5],
    ];
    const tris = [
      [0, 2, 1], [0, 3, 2], // bottom
      [3, 4, 5], [3, 5, 2], // back
      [0, 1, 5], [0, 5, 4], // slope
      [0, 4, 3], // left
      [1, 2, 5], // right
    ];
    const pos = [];
    for (const t of tris) for (const i of t) pos.push(...v[i]);
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    g.computeVertexNormals();
    return g;
  })(),
  corner: (() => {
    // CornerWedgePart: a pyramid whose apex sits above the right-back corner.
    const g = new THREE.BufferGeometry();
    const v = [[-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5, 0.5], [-0.5, -0.5, 0.5], [0.5, 0.5, 0.5]];
    const tris = [[0, 2, 1], [0, 3, 2], [0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]];
    const pos = [];
    for (const t of tris) for (const i of t) pos.push(...v[i]);
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    g.computeVertexNormals();
    return g;
  })(),
};

const matCache = new Map();
function material(p) {
  const opacity = 1 - Number(p.t || 0);
  const key = `${p.m}|${p.col.join(",")}|${opacity.toFixed(2)}`;
  let m = matCache.get(key);
  if (m) return m;
  const color = srgb(p.col);
  const transparent = opacity < 0.999;
  const common = { transparent, opacity, depthWrite: !transparent || opacity > 0.6, side: THREE.DoubleSide };
  switch (p.m) {
    case "Neon":
      m = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(2.2), ...common });
      break;
    case "Glass":
      m = new THREE.MeshStandardMaterial({ color, roughness: 0.08, metalness: 0.1, emissive: color.clone().multiplyScalar(0.15), ...common, transparent: true, opacity: Math.min(opacity, 0.55) });
      break;
    case "ForceField":
      m = new THREE.MeshBasicMaterial({ color, ...common, transparent: true, opacity: opacity * 0.4, blending: THREE.AdditiveBlending, depthWrite: false });
      break;
    case "Metal":
    case "DiamondPlate":
    case "CorrodedMetal":
      m = new THREE.MeshStandardMaterial({ color, roughness: 0.35, metalness: 0.7, ...common });
      break;
    case "Marble":
    case "SmoothPlastic":
    case "Plastic":
      m = new THREE.MeshStandardMaterial({ color, roughness: 0.55, metalness: 0.0, ...common });
      break;
    default:
      m = new THREE.MeshStandardMaterial({ color, roughness: 0.9, metalness: 0.0, ...common });
  }
  matCache.set(key, m);
  return m;
}

function partMesh(p) {
  let geo = GEO.box;
  if (p.c === "WedgePart") geo = GEO.wedge;
  else if (p.c === "CornerWedgePart") geo = GEO.corner;
  else if (p.mesh === "Sphere") geo = GEO.sphere;
  else if (p.mesh === "Cylinder") geo = GEO.meshCyl;
  else if (p.sh === "Ball") geo = GEO.sphere;
  else if (p.sh === "Cylinder") geo = GEO.cyl;
  const mesh = new THREE.Mesh(geo, material(p));
  let [sx, sy, sz] = p.s;
  if (p.ms && p.mesh) {
    sx *= p.ms[0]; sy *= p.ms[1]; sz *= p.ms[2];
  }
  const c = p.cf;
  const m = new THREE.Matrix4();
  m.set(
    c[3] * sx, c[4] * sy, c[5] * sz, c[0],
    c[6] * sx, c[7] * sy, c[8] * sz, c[1],
    c[9] * sx, c[10] * sy, c[11] * sz, c[2],
    0, 0, 0, 1,
  );
  mesh.matrixAutoUpdate = false;
  mesh.matrix.copy(m);
  return mesh;
}

async function main() {
  const shot = await (await fetch(`shots/${shotName}.json`)).json();
  const theme = shot.theme;
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setSize(W, H);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = shot.exposure || 1.0;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  if (shot.cutZ !== null && shot.cutZ !== undefined) {
    renderer.clippingPlanes = [new THREE.Plane(new THREE.Vector3(0, 0, -1), shot.cutZ)];
  }
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const fogColor = srgb(theme.fog);
  scene.background = fogColor.clone().multiplyScalar(0.6);
  if (!shot.cutZ) scene.fog = new THREE.FogExp2(fogColor, 1.25 / theme.fogEnd);
  scene.add(new THREE.AmbientLight(srgb(theme.ambient), 2.4));
  scene.add(new THREE.HemisphereLight(srgb(theme.outdoor), 0x000000, 0.8));

  const camera = new THREE.PerspectiveCamera(shot.fov || 70, W / H, 0.3, 4000);
  camera.position.set(...shot.eye);
  camera.lookAt(new THREE.Vector3(...shot.target));

  // Terrain.
  if (shot.terrain) {
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(decode(shot.terrain.pos, Float32Array), 3));
    const cols = decode(shot.terrain.col, Float32Array);
    // Vertex colours arrive as sRGB; convert to linear for lighting.
    for (let i = 0; i < cols.length; i++) cols[i] = Math.pow(cols[i], 2.2);
    g.setAttribute("color", new THREE.BufferAttribute(cols, 3));
    g.setIndex(new THREE.BufferAttribute(decode(shot.terrain.idx, Uint32Array), 1));
    g.computeVertexNormals();
    scene.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, side: THREE.DoubleSide })));
  }

  for (const p of shot.parts) scene.add(partMesh(p));

  // Lights: the ones nearest the view.
  const focus = new THREE.Vector3(...shot.target);
  const lights = shot.lights
    .map((l) => ({ ...l, d: focus.distanceTo(new THREE.Vector3(...l.p)) }))
    .sort((a, b) => a.d - b.d)
    .slice(0, MAX_LIGHTS);
  for (const l of lights) {
    const light = new THREE.PointLight(srgb(l.col), l.b * 5, l.r, 0.8);
    light.position.set(...l.p);
    scene.add(light);
  }

  // Particle clouds as a snapshot of floating motes.
  const rng = (() => { let s = 12345; return () => ((s = (s * 16807) % 2147483647) / 2147483647); })();
  for (const pe of shot.pe) {
    const n = Math.min(60, Math.max(4, Math.round(pe.rate * 1.5)));
    const pos = [];
    for (let i = 0; i < n; i++) {
      pos.push(pe.p[0] + (rng() - 0.5) * (pe.s[0] + 4), pe.p[1] + (rng() - 0.5) * (pe.s[1] + 4), pe.p[2] + (rng() - 0.5) * (pe.s[2] + 4));
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.Points(g, new THREE.PointsMaterial({ color: srgb(pe.col, 1.5), size: 0.35, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false })));
  }

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  composer.addPass(new UnrealBloomPass(new THREE.Vector2(W, H), 0.55, 0.6, 0.82));
  composer.addPass(new OutputPass());
  composer.render();
  window.__done = true;
}

main().catch((e) => {
  window.__error = String(e && e.stack || e);
});
