# threejs-builder scripts

## FBX forward/anchor calibration helper

This skill includes a small ES-module you can copy into your project to make the **reference frame contract** visible (axes, bounds, and mesh-forward arrow) for FBX models.

Install into your project:

```bash
python3 .claude/skills/threejs-builder/scripts/install-fbx-calibration-helpers.py \
  --out ./fbx-calibration-helpers.mjs
```

Use in your Three.js ES-module code:

```js
import { attachFbxCalibrationHelpers } from './fbx-calibration-helpers.mjs';

// After you normalize/anchor/scale the model, and after any yaw offsets:
attachFbxCalibrationHelpers({ scene, root: modelRoot, label: 'Hero', showGrid: true });
```

Notes:
- In Three.js, an Object3D's "forward" direction is its local `-Z` axis.
- `root.getWorldDirection(v)` gives you the world-space direction of local `-Z`.
