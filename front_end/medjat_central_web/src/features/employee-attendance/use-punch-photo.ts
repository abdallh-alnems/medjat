"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/**
 * Camera capture for a punch photo.
 *
 * The image is evidence for a human, never an input to a decision — nothing
 * scores it and nothing matches it. It is downscaled hard before upload:
 * a 640px JPEG is more than a manager needs to recognise a face, and the
 * employee is often on mobile data.
 */

const MAX_EDGE = 640;
const JPEG_QUALITY = 0.7;

export type CameraState = "idle" | "starting" | "ready" | "denied" | "unavailable";

export function usePunchPhoto(enabled: boolean) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [state, setState] = useState<CameraState>("idle");

  const stop = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
  }, []);

  const start = useCallback(async () => {
    if (!enabled) return;
    if (typeof navigator === "undefined" || !navigator.mediaDevices?.getUserMedia) {
      setState("unavailable");
      return;
    }

    setState("starting");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 720 } },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play().catch(() => undefined);
      }
      setState("ready");
    } catch (err) {
      // A refusal and a missing camera need different words to the employee:
      // one they can fix, the other they cannot.
      const name = (err as DOMException)?.name;
      setState(name === "NotAllowedError" || name === "SecurityError" ? "denied" : "unavailable");
    }
  }, [enabled]);

  // Release the camera when the component goes away. A live indicator light
  // after the employee has finished is alarming and looks like surveillance.
  useEffect(() => stop, [stop]);

  /** Returns a data URL, or null when no frame could be taken. */
  const capture = useCallback((): string | null => {
    const video = videoRef.current;
    if (!video || state !== "ready" || !video.videoWidth) return null;

    const scale = Math.min(1, MAX_EDGE / Math.max(video.videoWidth, video.videoHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(video.videoWidth * scale);
    canvas.height = Math.round(video.videoHeight * scale);

    const ctx = canvas.getContext("2d");
    if (!ctx) return null;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    return canvas.toDataURL("image/jpeg", JPEG_QUALITY);
  }, [state]);

  return { videoRef, state, start, stop, capture };
}
