# TODO

## Build mode
1. Rotate object around cursor tile position.
2. Move objects atop the currently moving object.
3. Refactor the objects list to a json to easily add & edit the objects.
4. Add light objects
5. Create the notion of "room".
6. Create rooms when walls are added.
7. Light up the room walls & objects when a light / window is added to it.
8. Roof:
    1. Create Roof meshs (think of "tiny life" but with actually corner wall).
        - I want 3 types of roof types:
            - Flat
            - Hip (pyramid)
            - Pent ( /\ )
    2. Create the roof system.
        - Select type of roof.
        - Click & drag to place the roof.
        - Allow Pent roof to cross eachother to form gable.
    3. Toggle the roof with a button.
9. Refactor the tile intersect and wall paint and any system that rely on camera being 2:1 isometric to not longer be.
    1. Change de camera to a 45d, 35.2764d

## Player character
1. Create player character mesh (think chibi).
2. Load player character mesh.
3. Move player character on click on the world.

## Animation system
1. Add bone animation to player character.
2. Create walk animation.
3. Load animation data with gltf.
4. Create animation system.
5. Have player character do the walk animation when walking.

