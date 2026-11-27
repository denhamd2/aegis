# ricochet_plugin_commands.md — four commands the editor bridge needs

Sketches for the four handlers that would make the mesh check in
`ricochet_mesh_check.md` doable without sitting at the editor.

**Read this first.** The plugin's source is not in this repo, so these are
written against the bridge's *observed* behaviour, not its code: the request
envelope is `{"type": "<command>", "params": {...}}` on one JSON line, success
is `{"status": "success", "result": {...}}`, errors are
`{"status": "error", "error": "<message>"}`, and the existing handlers validate
params with messages like `Missing 'name' parameter` and `Actor not found: X`.
The dispatch table, the owning class and the helpers (`FindActorByName`,
`Error`) are deliberately left abstract — drop the bodies into whatever your
dispatcher already looks like, and keep its envelope so the client needs no
change.

Compiled nowhere. Nothing here has been built against UE5.

---

## 1. `get_skeletal_mesh_info`

```cpp
// params: { "name": "<actor name>" }
TSharedPtr<FJsonObject> HandleGetSkeletalMeshInfo(const TSharedPtr<FJsonObject>& Params)
{
    FString Name;
    if (!Params->TryGetStringField(TEXT("name"), Name))
        return Error(TEXT("Missing 'name' parameter"));

    AActor* Actor = FindActorByName(Name);
    if (!Actor)
        return Error(FString::Printf(TEXT("Actor not found: %s"), *Name));

    USkeletalMeshComponent* Skel = Actor->FindComponentByClass<USkeletalMeshComponent>();
    if (!Skel)
        return Error(FString::Printf(TEXT("No SkeletalMeshComponent on %s"), *Name));

    USkeletalMesh* Mesh = Skel->GetSkeletalMeshAsset();   // UE5.1+; earlier: Skel->SkeletalMesh
    if (!Mesh)
        return Error(FString::Printf(TEXT("SkeletalMeshComponent on %s has no mesh"), *Name));

    TSharedPtr<FJsonObject> Result = MakeShared<FJsonObject>();
    Result->SetStringField(TEXT("actor"), Name);
    Result->SetStringField(TEXT("mesh"),
        Mesh->GetPathName());                              // shows whether it is his or the base rig's
    Result->SetStringField(TEXT("skeleton"),
        Mesh->GetSkeleton() ? Mesh->GetSkeleton()->GetPathName() : TEXT(""));
    Result->SetStringField(TEXT("anim_class"),
        Skel->GetAnimInstance() ? Skel->GetAnimInstance()->GetClass()->GetName() : TEXT(""));

    const FReferenceSkeleton& Ref = Mesh->GetRefSkeleton();
    TArray<TSharedPtr<FJsonValue>> Bones;
    for (int32 i = 0; i < Ref.GetNum(); ++i)
    {
        TSharedPtr<FJsonObject> Bone = MakeShared<FJsonObject>();
        Bone->SetStringField(TEXT("name"), Ref.GetBoneName(i).ToString());
        Bone->SetNumberField(TEXT("index"), i);
        Bones.Add(MakeShared<FJsonValueObject>(Bone));
    }
    Result->SetArrayField(TEXT("bones"), Bones);
    Result->SetNumberField(TEXT("bone_count"), Ref.GetNum());   // 65 for his Mixamo rig

    return Success(Result);
}
```

The bone count alone separates his rig from the base rig in one call, which is
the question the moveset doc could not answer from outside.

## 2. `play_montage`

```cpp
// params: { "name": "<actor>", "montage": "/Game/.../AM_PoisonRana_1",
//           "start_time": 0.0, "rate": 1.0, "pause": true }
TSharedPtr<FJsonObject> HandlePlayMontage(const TSharedPtr<FJsonObject>& Params)
{
    FString Name, MontagePath;
    if (!Params->TryGetStringField(TEXT("name"), Name))
        return Error(TEXT("Missing 'name' parameter"));
    if (!Params->TryGetStringField(TEXT("montage"), MontagePath))
        return Error(TEXT("Missing 'montage' parameter"));

    const double StartTime = Params->HasField(TEXT("start_time"))
        ? Params->GetNumberField(TEXT("start_time")) : 0.0;
    const double Rate = Params->HasField(TEXT("rate"))
        ? Params->GetNumberField(TEXT("rate")) : 1.0;
    const bool bPause = Params->HasField(TEXT("pause"))
        ? Params->GetBoolField(TEXT("pause")) : true;

    AActor* Actor = FindActorByName(Name);
    if (!Actor)
        return Error(FString::Printf(TEXT("Actor not found: %s"), *Name));
    USkeletalMeshComponent* Skel = Actor->FindComponentByClass<USkeletalMeshComponent>();
    if (!Skel || !Skel->GetAnimInstance())
        return Error(FString::Printf(TEXT("No anim instance on %s"), *Name));

    UAnimMontage* Montage = LoadObject<UAnimMontage>(nullptr, *MontagePath);
    if (!Montage)
        return Error(FString::Printf(TEXT("Montage not found: %s"), *MontagePath));

    UAnimInstance* Anim = Skel->GetAnimInstance();
    Anim->Montage_Play(Montage, Rate);
    // Playing then seeking is deliberate: Montage_SetPosition needs the montage
    // active, and pausing after the seek is what makes a single frame readable.
    Anim->Montage_SetPosition(Montage, StartTime);
    if (bPause)
        Anim->Montage_Pause(Montage);

    TSharedPtr<FJsonObject> Result = MakeShared<FJsonObject>();
    Result->SetStringField(TEXT("actor"), Name);
    Result->SetStringField(TEXT("montage"), MontagePath);
    Result->SetNumberField(TEXT("length"), Montage->GetPlayLength());
    Result->SetNumberField(TEXT("position"), Anim->Montage_GetPosition(Montage));
    Result->SetBoolField(TEXT("paused"), bPause);
    return Success(Result);
}
```

`length` in seconds is what turns the doc's frame numbers into seek times:
`start_time = frame / 60` for the 60 Hz clips.

## 3. `get_anim_pose`

```cpp
// params: { "name": "<actor>", "advance": 0.0, "bones": ["hand_r", "head"] (optional) }
TSharedPtr<FJsonObject> HandleGetAnimPose(const TSharedPtr<FJsonObject>& Params)
{
    FString Name;
    if (!Params->TryGetStringField(TEXT("name"), Name))
        return Error(TEXT("Missing 'name' parameter"));

    AActor* Actor = FindActorByName(Name);
    if (!Actor)
        return Error(FString::Printf(TEXT("Actor not found: %s"), *Name));
    USkeletalMeshComponent* Skel = Actor->FindComponentByClass<USkeletalMeshComponent>();
    if (!Skel)
        return Error(FString::Printf(TEXT("No SkeletalMeshComponent on %s"), *Name));

    UAnimInstance* Anim = Skel->GetAnimInstance();
    UAnimMontage* Montage = Anim ? Anim->GetCurrentActiveMontage() : nullptr;

    if (Anim && Montage && Params->HasField(TEXT("advance")))
    {
        const double Step = Params->GetNumberField(TEXT("advance"));
        if (Step != 0.0)   // one-frame stepping: pass 1/60 to walk the active window
            Anim->Montage_SetPosition(Montage,
                FMath::Max(0.0, Anim->Montage_GetPosition(Montage) + Step));
    }

    TArray<FString> Wanted;
    const TArray<TSharedPtr<FJsonValue>>* BonesJson = nullptr;
    if (Params->TryGetArrayField(TEXT("bones"), BonesJson))
        for (const auto& Value : *BonesJson) Wanted.Add(Value->AsString());

    TArray<TSharedPtr<FJsonValue>> Out;
    const FReferenceSkeleton& Ref = Skel->GetSkeletalMeshAsset()->GetRefSkeleton();
    for (int32 i = 0; i < Ref.GetNum(); ++i)
    {
        const FString BoneName = Ref.GetBoneName(i).ToString();
        if (Wanted.Num() && !Wanted.Contains(BoneName))
            continue;   // the whole skeleton is 65 entries; filter when you only need the hands

        const FTransform World = Skel->GetBoneTransform(i, Skel->GetComponentTransform());
        const FVector Loc = World.GetLocation();
        TArray<TSharedPtr<FJsonValue>> LocJson = {
            MakeShared<FJsonValueNumber>(Loc.X),
            MakeShared<FJsonValueNumber>(Loc.Y),
            MakeShared<FJsonValueNumber>(Loc.Z) };
        TSharedPtr<FJsonObject> Bone = MakeShared<FJsonObject>();
        Bone->SetStringField(TEXT("bone"), BoneName);
        Bone->SetArrayField(TEXT("world"), LocJson);
        Out.Add(MakeShared<FJsonValueObject>(Bone));
    }

    TSharedPtr<FJsonObject> Result = MakeShared<FJsonObject>();
    Result->SetStringField(TEXT("actor"), Name);
    Result->SetNumberField(TEXT("montage_position"),
        (Anim && Montage) ? Anim->Montage_GetPosition(Montage) : -1.0);
    Result->SetArrayField(TEXT("bones"), Out);
    return Success(Result);
}
```

`GetBoneTransform` is UE5.1+. On earlier engines read
`Skel->GetBoneMatrix(i)` and transform it by the component matrix instead.

World-space bone positions are the whole point: they say whether the hand
actually arrived at the target's head, which is the +16.7% reach question.

## 4. `take_screenshot` with the image in the response

The existing handler writes a file and returns its path, which is useless across
a tunnel. Add an opt-in field rather than changing the old behaviour:

```cpp
// existing params: { "filepath": "..." }
// added param:     { "return_base64": true }
bool bReturnBase64 = false;
Params->TryGetBoolField(TEXT("return_base64"), bReturnBase64);

if (bReturnBase64)
{
    TArray<FColor> Pixels;
    FIntPoint Size;
    if (!CaptureViewportPixels(Pixels, Size))          // your existing capture path
        return Error(TEXT("Screenshot capture failed"));

    TArray<uint8> Png;
    FImageUtils::CompressImageArray(Size.X, Size.Y, Pixels, Png);
    const FString B64 = FBase64::Encode(Png);

    TSharedPtr<FJsonObject> Result = MakeShared<FJsonObject>();
    Result->SetStringField(TEXT("format"), TEXT("png"));
    Result->SetNumberField(TEXT("width"), Size.X);
    Result->SetNumberField(TEXT("height"), Size.Y);
    Result->SetStringField(TEXT("base64"), B64);
    return Success(Result);
}
```

Two caveats worth deciding before writing it:

- **Size.** A 1080p PNG is ~1–2 MB, ~2.7 MB base64, and the bridge's reader
  accumulates until the buffer parses as JSON. Downscale to half before
  encoding, or the client's loop needs a byte budget.
- **Timing.** The shot must be taken after the pose is applied and the frame is
  drawn, i.e. the next tick, or you capture the previous pose. A
  `take_screenshot` that pulls the montage position back in the same response
  removes the ambiguity.

---

## Order to build them

1. `get_skeletal_mesh_info` — one call, and it settles whether his 65-bone mesh
   is the one on the actor.
2. `play_montage` + `get_anim_pose` — together they replace sitting at the
   editor and scrubbing; the pose arrays are the actual evidence.
3. `return_base64` — nice for a picture, but the pose numbers answer the reach
   question more precisely than 60 fps capture does.
