////////////////////////////////////////////////////////////
//
// SFML - Simple and Fast Multimedia Library
// Copyright (C) 2007-2013 Laurent Gomila (laurent.gom@gmail.com)
//
// This software is provided 'as-is', without any express or implied warranty.
// In no event will the authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it freely,
// subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented;
//    you must not claim that you wrote the original software.
//    If you use this software in a product, an acknowledgment
//    in the product documentation would be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such,
//    and must not be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source distribution.
//
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// Headers
////////////////////////////////////////////////////////////
#include <SFML/Window/iOS/EaglContext.hpp>
#include <SFML/Window/iOS/WindowImplUIKit.hpp>
#include <SFML/Window/iOS/SFView.hpp>
#include <SFML/System/Err.hpp>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES1/glext.h>


namespace sf
{
namespace priv
{
////////////////////////////////////////////////////////////
EaglContext::EaglContext(EaglContext* shared) :
m_context    (nil),
m_framebuffer(0),
m_colorbuffer(0),
m_depthbuffer(0)
{
    // Create the context
    if (shared)
        m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:[shared->m_context sharegroup]];
    else
        m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
}

    
////////////////////////////////////////////////////////////
EaglContext::EaglContext(EaglContext* shared, const ContextSettings& settings,
                         const WindowImpl* owner, unsigned int bitsPerPixel) :
m_context    (nil),
m_framebuffer(0),
m_colorbuffer(0),
m_depthbuffer(0)
{
    const WindowImplUIKit* window = static_cast<const WindowImplUIKit*>(owner);

    createContext(shared, window, bitsPerPixel, settings);
}


////////////////////////////////////////////////////////////
EaglContext::EaglContext(EaglContext* shared, const ContextSettings& settings, 
                         unsigned int width, unsigned int height) :
m_context    (nil),
m_framebuffer(0),
m_colorbuffer(0),
m_depthbuffer(0)
{
    // This constructor shoult never be used by implementation
    err() << "Calling bad EaglContext constructor, please contact your developer :)" << std::endl;
}


////////////////////////////////////////////////////////////
EaglContext::~EaglContext()
{
    if (m_context)
    {
        // Activate the context, so that we can destroy the buffers
        EAGLContext* previousContext = [EAGLContext currentContext];
        [EAGLContext setCurrentContext:m_context];
    
        // Destroy the buffers
        if (m_framebuffer)
            glDeleteFramebuffersOES(1, &m_framebuffer);
        if (m_colorbuffer)
            glDeleteRenderbuffersOES(1, &m_colorbuffer);
        if (m_depthbuffer)
            glDeleteRenderbuffersOES(1, &m_depthbuffer);

        // Restore the previous context
        [EAGLContext setCurrentContext:previousContext];

        // Release the context
        [m_context release];
    }
}


////////////////////////////////////////////////////////////
void EaglContext::recreateRenderBuffers(SFView* glView)
{
    // Activate the context
    EAGLContext* previousContext = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:m_context];

    // Bind the frame buffer
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_framebuffer);

    // Destroy previous render-buffers
    if (m_colorbuffer)
        glDeleteRenderbuffersOES(1, &m_colorbuffer);
    if (m_depthbuffer)
        glDeleteRenderbuffersOES(1, &m_depthbuffer);

    // Create the color buffer
    glGenRenderbuffersOES(1, &m_colorbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_colorbuffer);
    if (glView)
        [m_context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:glView.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, m_colorbuffer);

    // Create a depth buffer if requested
    if (m_settings.depthBits > 0)
    {
        // Find the best internal format
        GLenum format = m_settings.depthBits > 16 ? GL_DEPTH_COMPONENT24_OES : GL_DEPTH_COMPONENT16_OES;

        // Get the size of the color-buffer (which fits the current size of the GL view)
        GLint width, height;
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);

        // Create the depth buffer
        glGenRenderbuffersOES(1, &m_depthbuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_depthbuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, format, width, height);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, m_depthbuffer);
    }

    // Make sure that everything's ok
    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if (status != GL_FRAMEBUFFER_COMPLETE_OES)
        err() << "Failed to create a valid frame buffer (error code: " << status << ")" << std::endl;

    // Restore the previous context
    [EAGLContext setCurrentContext:previousContext];
}

    
////////////////////////////////////////////////////////////
bool EaglContext::makeCurrent()
{
    return [EAGLContext setCurrentContext:m_context];
}


////////////////////////////////////////////////////////////
void EaglContext::display()
{
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_colorbuffer);
    [m_context presentRenderbuffer:GL_RENDERBUFFER_OES];
}


////////////////////////////////////////////////////////////
void EaglContext::setVerticalSyncEnabled(bool enabled)
{
}

    
////////////////////////////////////////////////////////////
void EaglContext::createContext(EaglContext* shared,
                                const WindowImplUIKit* window,
                                unsigned int bitsPerPixel, 
                                const ContextSettings& settings)
{
    // Save the settings
    m_settings = settings;

    // Adjust the depth buffer format to those available
    if (m_settings.depthBits > 16)
        m_settings.depthBits = 24;
    else if (m_settings.depthBits > 0)
        m_settings.depthBits = 16;

    // Create the context
    if (shared)
        m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:[shared->m_context sharegroup]];
    else
        m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];

    // Activate it
    makeCurrent();

    // Create the framebuffer (this is the only allowed drawable on iOS)
    glGenFramebuffersOES(1, &m_framebuffer);

    // Create the render buffers
    recreateRenderBuffers(window->getGlView());

    // Attach the context to the GL view for future updates
    window->getGlView().context = this;
}

} // namespace priv

} // namespace sf
